module Orders
  # Creates or updates a draft SalesOrder. Does not run credit checks or submit the order.
  #
  # Usage:
  #   Orders::DraftUpsertService.call(actor: current_user, params: params_hash, organization: org, branch: branch)
  #
  class DraftUpsertService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, params:, organization:, branch:)
      @actor        = actor
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @organization = organization
      @branch       = branch
    end

    def call
      if @params[:id].present?
        update_draft
      else
        create_draft
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: nil, errors: [e.message] }
    end

    private

    def create_draft
      order = SalesOrder.new(
        organization: @organization,
        branch:       @branch,
        created_by:   @actor
      )

      assign_attrs(order, @params)

      ActiveRecord::Base.transaction do
        order.save!
        order.recalculate_totals!

        # If actor is a customer, run a credit precheck so we can surface warnings
        if customer_actor? && order.lines.present?
          credit_account = order.customer&.credit_account
          credit_result = Credit::PrecheckService.call(
            credit_account: credit_account,
            product_ids:    order.lines.map(&:product_id),
            order_total:    order.total_amount.to_f,
            branch:         @branch
          )

          # Persist snapshot as a preview so frontend can show potential issues
          order.update_columns(
            credit_snapshot: (credit_result[:metrics] || {}),
            credit_reasons:  (credit_result[:reasons] || [])
          )

          # Enforce hard block policy at draft-time for customer actors: prevent save
          if credit_result[:decision] == Credit::CreditEngine::DECISION_BLOCKED && order.customer&.credit_block_rule == 'hard_block'
            raise ActiveRecord::RecordInvalid.new(order), 'Order blocked by credit policy'
          end
        end

        { ok: true, order: order.reload, errors: [] }
      end
    end

    def update_draft
      order = SalesOrder.where(id: @params[:id], organization_id: @organization.id).first
      return { ok: false, order: nil, errors: ['Order not found'] } unless order
      return { ok: false, order: order, errors: ['Order is not editable'] } unless order.editable?

      assign_attrs(order, @params)

      ActiveRecord::Base.transaction do
        order.save!
        order.recalculate_totals!

        if customer_actor? && order.lines.present?
          credit_account = order.customer&.credit_account
          credit_result = Credit::PrecheckService.call(
            credit_account: credit_account,
            product_ids:    order.lines.map(&:product_id),
            order_total:    order.total_amount.to_f,
            branch:         @branch
          )

          order.update_columns(
            credit_snapshot: (credit_result[:metrics] || {}),
            credit_reasons:  (credit_result[:reasons] || [])
          )

          if credit_result[:decision] == Credit::CreditEngine::DECISION_BLOCKED && order.customer&.credit_block_rule == 'hard_block'
            raise ActiveRecord::RecordInvalid.new(order), 'Order blocked by credit policy'
          end
        end

        { ok: true, order: order.reload, errors: [] }
      end
    end

    def customer_actor?
      return false unless @actor.respond_to?(:membership_for)
      role = @actor.membership_for(@organization)&.name || @actor.membership_for(@organization)&.role&.name
      role == 'customer' || @actor.memberships.active.exists?(organization: @organization, role: Role.find_by(name: 'customer'))
    end

    # Assign allowed attributes and nested lines (if provided)
    def assign_attrs(order, attrs)
      permitted = attrs.slice(:customer_id, :delivery_date, :notes, :idempotency_key)
      order.assign_attributes(permitted)

      if attrs[:lines_attributes].present?
        order.lines_attributes = attrs[:lines_attributes]
      end
    end
  end
end
module Orders
  # Creates or updates a draft SalesOrder with its lines.
  #
  # Usage:
  #   result = Orders::DraftUpsertService.call(
  #     actor:         current_user,
  #     organization:  current_organization,
  #     branch:        branch,
  #     customer:      customer,
  #     params:        { delivery_date:, notes:, lines: [...] },
  #     order:         existing_order_or_nil   # nil → create new draft
  #   )
  #   result[:ok]     # => true | false
  #   result[:order]  # => SalesOrder instance
  #   result[:errors] # => []
  #
  class DraftUpsertService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, organization:, branch:, customer:, params:, order: nil)
      @actor        = actor
      @organization = organization
      @branch       = branch
      @customer     = customer
      @params       = params
      @order        = order
    end

    def call
      ActiveRecord::Base.transaction do
        if @order
          update_draft!
        else
          create_draft!
        end

        build_lines! if @params[:lines].present?
        apply_draft_schemes! if @params[:lines].present?

        @order.recalculate_totals!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @organization,
          auditable:    @order,
          action:       @order.previously_new_record? ? 'order_created' : 'order_updated',
          changes:      { status: @order.status, total_amount: @order.total_amount },
          reason:       nil
        )

        { ok: true, order: @order, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end

    private

    def create_draft!
      @order = SalesOrder.create!(
        organization:  @organization,
        branch:        @branch,
        customer:      @customer,
        created_by:    @actor,
        status:        'draft',
        delivery_date: @params[:delivery_date],
        notes:         @params[:notes]
      )
    end

    def update_draft!
      raise ActiveRecord::RecordInvalid.new(@order) unless @order.editable?

      @order.update!(
        delivery_date: @params[:delivery_date] || @order.delivery_date,
        notes:         @params.key?(:notes) ? @params[:notes] : @order.notes
      )
    end

    def build_lines!
      # Replace all lines with the submitted set
      @order.lines.destroy_all

      Array(@params[:lines]).each do |line_attrs|
        product = Product.active.find(line_attrs[:product_id])
        price_result = resolve_price(product, line_attrs[:qty])

        @order.lines.create!(
          product:      product,
          qty:          line_attrs[:qty],
          unit_price:   line_attrs[:unit_price].present? ? line_attrs[:unit_price] : price_result.unit_price,
          discount_pct: line_attrs[:discount_pct].presence || price_result.discount_pct || 0,
          price_source: line_attrs[:unit_price].present? ? 'manual' : price_result.source,
          price_list_id: price_result.price_list_id,
          hsn_code:     product.hsn_code,
          gst_rate:     product.gst_rate
        )
      end
    end

    def resolve_price(product, qty)
      Pricing::EffectivePriceResolver.call(
        product:  product,
        branch:   @branch,
        retailer: @customer,
        qty:      qty.to_f,
        on_date:  Date.current
      )
    end

    def apply_draft_schemes!
      cart_lines = @order.lines.includes(:product).map do |line|
        {
          product_id:        line.product_id,
          product:           line.product,
          qty:               line.qty.to_f,
          base_unit_price:   line.unit_price.to_f,
          base_discount_pct: line.discount_pct.to_f,
          category_id:       line.product.product_category_id
        }
      end

      result = Pricing::ApplySchemesService.call(
        retailer:   @customer,
        branch_id:  @branch.id,
        cart_lines: cart_lines,
        context:    { date: Date.current }
      )

      @order.lines.each_with_index do |line, idx|
        pl = result.priced_lines[idx]
        next unless pl
        line.update_columns(
          scheme_discount_pct: pl[:scheme_discount_pct],
          scheme_tags:         pl[:scheme_tags].as_json
        )
      end
    rescue StandardError => e
      Rails.logger.warn("[DraftUpsertService] Scheme application skipped: #{e.message}")
    end
  end
end
