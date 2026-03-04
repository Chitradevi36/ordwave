class PriceListItem < ApplicationRecord
  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :price_list
  belongs_to :product

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :unit_price,   presence: true,
                           numericality: { greater_than: 0 }
  validates :discount_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                           allow_nil: true
  validates :min_qty,      numericality: { greater_than: 0 }, allow_nil: true

  # Uniqueness: one row per (price_list, product, min_qty)
  validates :min_qty, uniqueness: {
    scope: [:price_list_id, :product_id],
    message: 'A price already exists for this product and minimum quantity in this list'
  }

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :base_item,     -> { where(min_qty: nil) }
  scope :for_product,   ->(pid) { where(product_id: pid) }
  scope :qty_threshold, lambda { |qty|
    where('min_qty IS NULL OR min_qty <= ?', qty).order('min_qty DESC NULLS LAST')
  }

  # ── Instance helpers ────────────────────────────────────────────────────────
  def effective_price
    return unit_price if discount_pct.blank? || discount_pct.zero?

    unit_price * (1 - discount_pct / 100.0)
  end
end
