# frozen_string_literal: true

class SupplierDebitNoteLine < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :supplier_debit_note, inverse_of: :lines
  belongs_to :product
  belongs_to :return_line, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :qty,        numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :gst_rate,   numericality: { greater_than_or_equal_to: 0 }

  # ── Callbacks ────────────────────────────────────────────────────────────────
  before_validation :compute_totals

  private

  def compute_totals
    taxable   = (qty.to_d * unit_price.to_d).round(2)
    self.tax_amount = (taxable * gst_rate.to_d / 100).round(2)
    self.line_total = taxable + tax_amount
  end
end
