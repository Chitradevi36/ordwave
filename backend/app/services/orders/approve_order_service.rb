module Orders
  # Approves or rejects an on_hold or submitted order.
  #
  # Usage:
  #   result = Orders::ApproveOrderService.call(
  #     actor:    current_user,
  #     order:    sales_order,
  #     decision: 'approved' | 'rejected',
  #     reason:   "string"     # required for rejected
  #   )
  #
  class ApproveOrderService
    VALID_DECISIONS = %w[approved rejected].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, decision:, reason: nil)
      @actor    = actor
      @order    = order
      @decision = decision.to_s
      @reason   = reason
    end

    def call
      errors = validate
      return { ok: false, order: @order, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @order.transition_to!(@decision, reason: @reason)

        action = @decision == 'approved' ? 'order_approved' : 'order_rejected'
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       action,
          changes:      { status: @decision },
          reason:       @reason
        )

        # Auto-assign to a delivery trip on approval
        trip_result = nil
        pick_list   = nil
        if @decision == 'approved'
          trip_result = Delivery::AddOrderToTripService.call(actor: @actor, order: @order.reload)
          # Log but don't fail the approval if trip creation fails
          unless trip_result[:ok]
            Rails.logger.warn("[ApproveOrderService] Auto-trip failed for order #{@order.id}: #{trip_result[:errors].join(', ')}")
          end

          # Auto-create pick list so warehouse can start fulfillment immediately
          pick_list = create_pick_list_for_order(@order.reload)
        end

        # Notify order creator + warehouse staff of decision
        notify_on_decision

        # Reserve inventory for all order lines so stock can't be double-allocated
        reserve_result = Inventory::ReserveForOrder.call(sales_order: @order.reload, actor: @actor)
        unless reserve_result.success?
          Rails.logger.warn("[ApproveOrderService] Stock reservation failed for order #{@order.id}: #{reserve_result.errors.join(', ')}")
        end

        reloaded = @order.reload
        { ok: true, order: reloaded, errors: [], trip_result: trip_result, pick_list: pick_list }
      end.tap do |result|
        if result[:ok] && @decision == 'approved'
          WebhookEvents.fire(
            organization: result[:order].organization,
            event:        'order.approved',
            payload:      WebhookEvents.order_payload(result[:order])
          )
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end

    private

    def notify_on_decision
      type   = @decision == 'approved' ? 'order_approved' : 'order_rejected'
      title  = @decision == 'approved' ? "Order #{@order.order_number} approved" : "Order #{@order.order_number} rejected"
      body   = @reason.present? ? "Reason: #{@reason}" : @order.customer&.name
      link   = "/orders/#{@order.id}"

      recipients = [@order.created_by].compact

      if @decision == 'approved'
        warehouse = User.joins(:memberships)
                        .where(memberships: {
                          organization_id: @order.organization_id,
                          deleted_at:      nil,
                          active:          true
                        })
                        .joins(memberships: :role)
                        .where(roles: { name: 'warehouse_staff' })
                        .distinct
        recipients += warehouse.to_a
      end

      Notifications::CreateService.call(
        organization: @order.organization,
        recipients:   recipients.uniq,
        actor:        @actor,
        notifiable:   @order,
        type:         type,
        title:        title,
        body:         body,
        deep_link:    link,
        severity:     @decision == 'approved' ? 'medium' : 'high'
      )
    rescue StandardError => e
      Rails.logger.warn("[ApproveOrderService] Notification failed: #{e.message}")
    end

    def validate
      errs = []
      errs << "Invalid decision. Must be 'approved' or 'rejected'" unless VALID_DECISIONS.include?(@decision)
      errs << 'Order must be submitted or on_hold to approve or reject' unless @order.on_hold? || @order.submitted?
      errs << 'Reason is required when rejecting' if @decision == 'rejected' && @reason.blank?
      errs
    end

    def create_pick_list_for_order(order)
      pick_list = PickList.create!(
        organization: order.organization,
        branch:       order.branch,
        sales_order:  order,
        status:       'pending'
      )
      order.lines.each do |line|
        pick_list.pick_list_items.create!(
          product:       line.product,
          qty_requested: line.qty
        )
      end
      pick_list
    rescue StandardError => e
      Rails.logger.warn("[ApproveOrderService] PickList creation failed for order #{order.id}: #{e.message}")
      nil
    end
  end
end
