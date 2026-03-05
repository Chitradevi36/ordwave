class PurchaseInvoiceLine < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :purchase_invoice, inverse_of: :lines
  belongs_to :product
  belongs_to :hsn_sac_code, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :qty,          numericality: { greater_than: 0 }
  validates :unit_price,   numericality: { greater_than_or_equal_to: 0 }
  validates :discount_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :tax_rate,     numericality: { greater_than_or_equal_to: 0 }

  # ── Callbacks ─────────────────────────────────────────────────────────────────
  before_save :compute_line_total

  # ── Computed ──────────────────────────────────────────────────────────────────
  def subtotal
    return 0 unless qty && unit_price
    base = qty * unit_price
    base * (1 - (discount_pct || 0) / 100.0)
  end

  def compute_line_total
    taxable      = subtotal
    self.tax_amount = (taxable * (tax_rate || 0) / 100.0).round(2)
    self.line_total  = (taxable + tax_amount).round(2)
  end

  # Convenience: resolve HSN code record — falls back to the product's linked HSN
  def effective_hsn_sac_code
    hsn_sac_code || product&.hsn_sac_code
  end
end
