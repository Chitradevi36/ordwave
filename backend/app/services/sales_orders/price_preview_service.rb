module SalesOrders
  # Generates a full priced preview (base price + scheme discounts) for a
  # retailer cart without persisting anything.
  #
  # Usage:
  #   result = SalesOrders::PricePreviewService.call(
  #     retailer:  customer,
  #     branch:    branch,
  #     lines:     [{ product_id: 1, qty: 10 }, ...],
  #     context:   { route_id: 5, beat_id: nil, date: Date.current }
  #   )
  #
  # Returns a struct with:
  #   lines:   [{product_id, qty, base_price, base_discount_pct, scheme_discount_pct,
  #              final_price, line_total, scheme_tags}]
  #   freebies, order_discounts, totals, explain
  #
  class PricePreviewService
    Result = Struct.new(:lines, :freebies, :order_discounts, :totals, :explain, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(retailer:, branch:, lines:, context: {})
      @retailer = retailer
      @branch   = branch
      @lines    = lines
      @context  = context
    end

    def call
      cart_lines = build_cart_lines
      schemes_result = Pricing::ApplySchemesService.call(
        retailer:   @retailer,
        branch_id:  @branch.id,
        cart_lines: cart_lines,
        context:    @context
      )

      enriched = schemes_result.priced_lines.map do |pl|
        line_total = (pl[:final_price] * pl[:qty]).round(2)
        pl.merge(line_total: line_total)
      end

      Result.new(
        lines:           enriched,
        freebies:        schemes_result.freebies,
        order_discounts: schemes_result.order_discounts,
        totals:          schemes_result.totals,
        explain:         schemes_result.explain
      )
    end

    private

    def build_cart_lines
      @lines.map do |l|
        h = l.is_a?(Hash) ? l.transform_keys(&:to_sym) : l.to_h.transform_keys(&:to_sym)
        product = h[:product] || Product.active.find(h[:product_id])

        price_result = Pricing::EffectivePriceResolver.call(
          product:  product,
          branch:   @branch,
          retailer: @retailer,
          qty:      h[:qty].to_f,
          on_date:  (@context[:date]&.to_date || Date.current)
        )

        {
          product_id:        product.id,
          product:           product,
          qty:               h[:qty].to_f,
          base_unit_price:   price_result.unit_price,
          base_discount_pct: price_result.discount_pct.to_f,
          category_id:       product.product_category_id
        }
      end
    end
  end
end
