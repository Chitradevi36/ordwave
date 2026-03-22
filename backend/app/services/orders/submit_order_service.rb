module Orders
  # Submits a draft order: freezes line prices, runs credit engine, transitions status.
  #
  # Decision mapping:
  #   credit ok      → status: submitted
  #   credit hold    → status: on_hold
  #   credit blocked → status stays draft; credit snapshot persisted; returns ok: false
  #
  # Result always includes a :credit key with the full engine output.
  # Idempotency: if idempotency_key is provided and an already-submitted order with
  # that key exists for the org, returns that order without re-processing.
  #
  # Usage:
  #   result = Orders::SubmitOrderService.call(
  #     actor:           current_user,
  #     order:           sales_order,
  #     idempotency_key: params[:idempotency_key]   # optional
  #   )
  #
  class SubmitOrderService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, idempotency_key: nil)
      @actor           = actor
      @order           = order
      @idempotency_key = idempotency_key
    end

    def call
      # Idempotency guard
      if @idempotency_key.present?
        existing = SalesOrder
                     .not_deleted
                     .where(organization_id: @order.organization_id, idempotency_key: @idempotency_key)
                     .where.not(status: 'draft')
                     .first
        return { ok: true, order: existing, errors: [], idempotent: true, credit: nil } if existing
      end

      return { ok: false, order: @order, errors: ['Order is not in draft status'], credit: nil } unless @order.draft?
      return { ok: false, order: @order, errors: ['Order has no lines'],           credit: nil } if @order.lines.empty?

      ActiveRecord::Base.transaction do
        # 1. Freeze prices on lines
        freeze_line_prices!

        # 1b. Apply and freeze scheme discounts
        Orders::FreezeSchemesOnSubmitService.call(order: @order)

        # 2. Recalculate totals with all frozen prices + scheme discounts
        @order.recalculate_totals!

        # 3. Run credit engine
        credit_result = run_credit_check

        # 4. Always persist credit snapshot + idempotency_key (even on blocked)
        @order.update!(
          credit_decision:  credit_result[:decision],
          credit_snapshot:  credit_result[:metrics].to_h,
          credit_reasons:   credit_result[:reasons],
          idempotency_key:  @idempotency_key
        )

        # 5. Audit: credit checked (always)
        log_credit_checked(credit_result)

        # 6. BLOCKED → keep order as draft; caller renders 422
        if credit_result[:decision] == Credit::CreditEngine::DECISION_BLOCKED
          return { ok: false, order: @order.reload, errors: ['Order blocked by credit policy'],
                   credit: credit_result }
        end

        # 7. Transition state: ok → submitted, hold → on_hold
        new_status = map_credit_decision(credit_result[:decision])
        @order.transition_to!(new_status)

        # 8. Audit: state transition
        log_submission(credit_result)

        # 9. Auto-approve immediately if approval mode is automatic with 0 edit window
        auto_approve_immediately!(credit_result) if new_status == 'submitted'

        # 10. Notify branch managers
        notify_on_submission(new_status)

        reloaded = @order.reload
        { ok: true, order: reloaded, errors: [], credit: credit_result }
      end.tap do |result|
        if result[:ok]
          WebhookEvents.fire(
            organization: result[:order].organization,
            event:        'order.created',
            payload:      WebhookEvents.order_payload(result[:order])
          )
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message], credit: nil }
    end

    private

    def auto_approve_immediately!(credit_result)
      settings = @order.organization.settings || {}
      approval_mode = settings['order_approval_mode']
      edit_window_minutes = (settings['order_edit_window_minutes'] || 30).to_i
      approval_threshold = (settings['order_approval_threshold'] || 0).to_f

      should_approve = case approval_mode
                       when 'automatic'
                         edit_window_minutes == 0
                       when 'above_threshold'
                         @order.total_amount.to_f < approval_threshold && edit_window_minutes == 0
                       else
                         false
                       end

      return unless should_approve

      # Auto-approve immediately
      result = Orders::ApproveOrderService.call(
        actor:    system_actor,
        order:    @order,
        decision: 'approved',
        reason:   'Auto-approved on submission (edit window = 0)'
      )

      unless result[:ok]
        Rails.logger.warn("[SubmitOrderService] Immediate auto-approval failed for order #{@order.id}: #{result[:errors].join(', ')}")
      end
    end

    def system_actor
      # Use the submitting user as actor for approval
      # In a real scenario, you might want to create a "system" user
      @actor
    end

    def notify_on_submission(new_status)
      managers = User.joins(:memberships)
                     .where(memberships: {
                       organization_id: @order.organization_id,
                       deleted_at:      nil,
                       active:          true
                     })
                     .joins(memberships: :role)
                     .where(roles: { name: %w[owner admin manager] })
                     .distinct

      type   = new_status == 'on_hold' ? 'order_held'      : 'order_submitted'
      title  = new_status == 'on_hold' ? 'Order on hold — approval needed' : 'New order submitted'
      body   = "#{@order.customer&.name} — #{@order.order_number} (₹#{@order.total_amount&.to_i&.to_s(:delimited)})"
      link   = "/approvals"
      sev    = new_status == 'on_hold' ? 'high' : 'medium'

      Notifications::CreateService.call(
        organization: @order.organization,
        recipients:   managers,
        actor:        @actor,
        notifiable:   @order,
        type:         type,
        title:        title,
        body:         body,
        deep_link:    link,
        severity:     sev
      )
    rescue StandardError => e
      Rails.logger.warn("[SubmitOrderService] Notification failed: #{e.message}")
    end

    def freeze_line_prices!
      @order.lines.each do |line|
        next if line.price_source == 'manual'

        result = Pricing::EffectivePriceResolver.call(
          product:  line.product,
          branch:   @order.branch,
          retailer: @order.customer,
          qty:      line.qty.to_f,
          on_date:  Date.current
        )

        line.update!(
          unit_price:    result.unit_price,
          discount_pct:  result.discount_pct.to_f,
          price_source:  result.source,
          price_list_id: result.price_list_id
        )
      end
    end

    def run_credit_check
      credit_account = @order.customer.credit_account
      unless credit_account
        return { decision: 'ok', reasons: [], metrics: {}, actions_required: {} }
      end

      credit_account.with_lock do
        result = Credit::CreditEngine.evaluate_order(
          credit_account: credit_account,
          product_ids:    @order.lines.map(&:product_id),
          order_total:    @order.total_amount.to_f,
          on_date:        Date.current
        )

        # Enrich metrics with order-exposure breakdown so the UI can explain the
        # decision with full context (invoice outstanding + pipeline exposure).
        usage = Credit::RetailerCreditUsageService.call(
          retailer: @order.customer,
          branch:   @order.branch
        )
        result[:metrics] = result[:metrics].merge(
          order_exposure:      usage[:order_exposure],
          invoice_outstanding: usage[:invoice_outstanding],
          available_credit:    usage[:available_credit],
          credit_used_total:   usage[:credit_used_total],
          hold_exposure:       usage[:hold_exposure]
        )

        result
      end
    end

    def map_credit_decision(decision)
      case decision
      when 'ok'   then 'submitted'
      when 'hold' then 'on_hold'
      else             'submitted'
      end
    end

    # Audit: credit check result (always written, including blocked)
    def log_credit_checked(credit_result)
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @order.organization,
        auditable:    @order,
        action:       'order_credit_checked',
        changes:      { decision: credit_result[:decision], reasons: credit_result[:reasons],
                        metrics:  credit_result[:metrics] },
        reason:       nil
      )
    end

    # Audit: order transition events (ok / hold only — not called for blocked)
    def log_submission(credit_result)
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @order.organization,
        auditable:    @order,
        action:       'order_submitted',
        changes:      { status: @order.status, total_amount: @order.total_amount },
        reason:       nil
      )

      return unless @order.on_hold?

      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @order.organization,
        auditable:    @order,
        action:       'order_on_hold',
        changes:      { reasons: credit_result[:reasons] },
        reason:       nil
      )
    end
  end
end
