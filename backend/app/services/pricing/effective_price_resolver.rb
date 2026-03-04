module Pricing
  # Resolves the effective unit price for a product at a branch for a retailer.
  #
  # Priority: retailer_specific > tier_specific > promo > standard > missing
  #
  # Usage:
  #   result = Pricing::EffectivePriceResolver.call(
  #     product:  product,
  #     branch:   branch,
  #     retailer: customer,
  #     qty:      10,
  #     on_date:  Date.current
  #   )
  #
  class EffectivePriceResolver
    Result = Struct.new(
      :unit_price, :source, :price_list_id, :discount_pct,
      :min_qty_matched, :valid_from, :valid_to,
      keyword_init: true
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(product:, branch:, retailer:, qty: nil, on_date: Date.current)
      @product  = product
      @branch   = branch
      @retailer = retailer
      @qty      = qty
      @on_date  = on_date
    end

    def call
      try_retailer_specific ||
        try_tier_specific    ||
        try_promo            ||
        try_standard         ||
        missing_result
    end

    private

    # ── 1. Retailer-specific ──────────────────────────────────────────────────
    def try_retailer_specific
      return nil unless @retailer

      assignment = RetailerPriceListAssignment
                     .includes(:price_list)
                     .where(customer: @retailer, active: true)
                     .active_on(@on_date)
                     .joins(:price_list)
                     .where(price_lists: { status: 'active', list_type: 'retailer_specific' })
                     .first

      return nil unless assignment

      build_result(assignment.price_list, 'retailer_specific')
    end

    # ── 2. Tier-specific ─────────────────────────────────────────────────────
    def try_tier_specific
      return nil unless @retailer&.tier.present?

      assignment = TierPriceListAssignment
                     .includes(:price_list)
                     .where(branch: @branch, retailer_tier: @retailer.tier, active: true)
                     .active_on(@on_date)
                     .joins(:price_list)
                     .where(price_lists: { status: 'active', list_type: 'tier_specific' })
                     .first

      return nil unless assignment

      build_result(assignment.price_list, 'tier_specific')
    end

    # ── 3. Promo ─────────────────────────────────────────────────────────────
    def try_promo
      # Retailer-targeted promo assignments
      promo_lists = if @retailer
                      RetailerPriceListAssignment
                        .includes(:price_list)
                        .where(customer: @retailer, active: true)
                        .active_on(@on_date)
                        .joins(:price_list)
                        .where(price_lists: { status: 'active', list_type: 'promo' })
                        .map(&:price_list)
                    else
                      []
                    end

      promo_lists.each do |list|
        result = build_result(list, 'promo')
        return result if result
      end

      nil
    end

    # ── 4. Standard ──────────────────────────────────────────────────────────
    def try_standard
      list = PriceList.active_lists
                      .where(branch: @branch, list_type: 'standard')
                      .date_valid(@on_date)
                      .first

      return nil unless list

      build_result(list, 'standard')
    end

    # ── Result helpers ────────────────────────────────────────────────────────
    def build_result(price_list, source)
      item = best_item(price_list)
      return nil unless item

      Result.new(
        unit_price:     item.effective_price,
        source:         source,
        price_list_id:  price_list.id,
        discount_pct:   item.discount_pct,
        min_qty_matched: item.min_qty,
        valid_from:     price_list.valid_from,
        valid_to:       price_list.valid_to
      )
    end

    def best_item(price_list)
      items = price_list.items.for_product(@product.id)

      if @qty.present?
        # Best match: highest min_qty <= qty, fallback to nil (base)
        items.qty_threshold(@qty).first
      else
        # No qty: prefer base item (min_qty nil), then lowest threshold
        items.base_item.first || items.order('min_qty ASC NULLS FIRST').first
      end
    end

    def missing_result
      Result.new(
        unit_price:     nil,
        source:         'missing',
        price_list_id:  nil,
        discount_pct:   nil,
        min_qty_matched: nil,
        valid_from:     nil,
        valid_to:       nil
      )
    end
  end
end
