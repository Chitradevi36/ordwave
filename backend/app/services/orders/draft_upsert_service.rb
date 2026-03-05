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
