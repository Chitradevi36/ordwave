module Orders
  # Refreshes all non-manual lines with current effective prices from price lists.
  # Only works on draft orders.
  #
  # Usage:
  #   result = Orders::PriceRefreshService.call(actor: current_user, order: sales_order)
  #
  class PriceRefreshService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:)
      @actor = actor
      @order = order
    end

    def call
      return { ok: false, order: @order, errors: ['Order must be a draft to refresh prices'] } unless @order.draft?
      return { ok: false, order: @order, errors: ['Order has no lines'] } if @order.lines.empty?

      ActiveRecord::Base.transaction do
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

        @order.recalculate_totals!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       'order_price_refreshed',
          changes:      { total_amount: @order.total_amount },
          reason:       nil
        )

        { ok: true, order: @order.reload, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end
  end
end
