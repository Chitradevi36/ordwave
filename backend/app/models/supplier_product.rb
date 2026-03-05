class SupplierProduct < ApplicationRecord
  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :supplier
  belongs_to :product

  # ── Validations ───────────────────────────────────────────────────────────
  validates :supplier, :product, presence: true
  validates :product_id, uniqueness: {
    scope:   :supplier_id,
    message: 'is already mapped to this supplier'
  }
  validates :purchase_price,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :lead_time_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
