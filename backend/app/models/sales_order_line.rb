class SalesOrderLine < ApplicationRecord
  PRICE_SOURCES = %w[retailer_specific tier_specific promo standard manual missing].freeze

  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :sales_order, inverse_of: :lines
  belongs_to :product

  # ── Validations ──────────────────────────────────────────────────────────
  validates :qty,        presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :gst_rate,     numericality: { greater_than_or_equal_to: 0 }
  validates :price_source, inclusion: { in: PRICE_SOURCES }, allow_blank: true

  # ── Callbacks ─────────────────────────────────────────────────────────────
  before_save :compute_line_total

  # ── Scheme helpers ────────────────────────────────────────────────────────
  # Returns the combined discount (price list + scheme) as a single pct for UI
  def effective_discount_pct
    [discount_pct.to_f + scheme_discount_pct.to_f, 100.0].min
  end

  # ── Instance methods ──────────────────────────────────────────────────────
  def compute_line_total
    base = qty.to_f * unit_price.to_f
    total_discount = [discount_pct.to_f + scheme_discount_pct.to_f, 100.0].min
    discounted = base * (1 - total_discount / 100.0)
    self.line_total = discounted.round(2)
  end
end
