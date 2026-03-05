module Orders
  # Applies the scheme engine against the lines of a SalesOrder and
  # persists the results:
  #   - Writes scheme_discount_pct + scheme_tags to each SalesOrderLine
  #   - Creates SalesOrderFreebie records
  #   - Records a SchemeApplication with source: 'submit_snapshot'
  #   - Updates order.scheme_snapshot with the explain payload
  #   - Calls order.recalculate_totals!
  #
  # This should be called from SubmitOrderService *after* freeze_line_prices!
  #
  class FreezeSchemesOnSubmitService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(order:, context: {})
      @order   = order
      @context = context
    end

    def call
      cart_lines = build_cart_lines
      return if cart_lines.empty?

      result = Pricing::ApplySchemesService.call(
        retailer:   @order.customer,
        branch_id:  @order.branch_id,
        cart_lines: cart_lines,
        context:    @context.merge(date: Date.current)
      )

      ActiveRecord::Base.transaction do
        persist_line_schemes(result.priced_lines)
        persist_freebies(result.freebies)
        persist_snapshot(result)
        @order.recalculate_totals!
      end

      result
    end

    private

    def build_cart_lines
      @order.lines.includes(:product).map do |line|
        {
          product_id:        line.product_id,
          product:           line.product,
          qty:               line.qty.to_f,
          base_unit_price:   line.unit_price.to_f,
          base_discount_pct: line.discount_pct.to_f,
          category_id:       line.product.product_category_id
        }
      end
    end

    def persist_line_schemes(priced_lines)
      @order.lines.each_with_index do |line, idx|
        pl = priced_lines[idx]
        next unless pl

        line.update_columns(
          scheme_discount_pct: pl[:scheme_discount_pct],
          scheme_tags:         pl[:scheme_tags].as_json
        )
      end
    end

    def persist_freebies(freebies)
      @order.freebies.destroy_all
      freebies.each do |fb|
        SalesOrderFreebie.create!(
          sales_order_id: @order.id,
          scheme_id:      fb[:scheme_id],
          product_id:     fb[:product_id],
          qty_free:       fb[:qty_free],
          notes:          fb[:scheme_name]
        )
      end
    end

    def persist_snapshot(result)
      breakdown = {
        lines:                 result.priced_lines,
        freebies:              result.freebies,
        order_discounts:       result.order_discounts,
        discount_total:        result.totals[:scheme_discount_total],
        messages:              result.explain[:applied].map { |a| a[:message] }
      }

      SchemeApplication.create!(
        sales_order_id:  @order.id,
        organization_id: @order.organization_id,
        source:          'submit_snapshot',
        breakdown:       breakdown,
        applied_at:      Time.current
      )

      @order.update_column(:scheme_snapshot, result.explain.as_json)
    end
  end
end
