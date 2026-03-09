class ReturnQcItem < ApplicationRecord
  CONDITIONS_FINAL = %w[resalable damaged expired mixed discounted_resalable return_to_supplier].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :return_line,  inverse_of: :qc_item
  belongs_to :qc_by, class_name: 'User'

  # ── Validations ────────────────────────────────────────────────────────────
  validates :condition_final, inclusion: { in: CONDITIONS_FINAL }
  validates :qc_at,           presence: true
  validates :qty_resalable,              numericality: { greater_than_or_equal_to: 0 }
  validates :qty_damaged,                numericality: { greater_than_or_equal_to: 0 }
  validates :qty_expired,                numericality: { greater_than_or_equal_to: 0 }
  validates :qty_discounted_resalable,   numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :qty_return_to_supplier,     numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :discount_pct,               numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :supplier_return_reason,     inclusion: { in: SupplierDebitNote::REASONS }, allow_nil: true

  validate :total_does_not_exceed_reported
  validate :discount_pct_required_for_discounted_resalable

  # ── Helpers ────────────────────────────────────────────────────────────────
  def total_accounted
    qty_resalable.to_d +
      qty_damaged.to_d +
      qty_expired.to_d +
      qty_discounted_resalable.to_d +
      qty_return_to_supplier.to_d
  end

  def total_restorable
    qty_resalable.to_d + qty_discounted_resalable.to_d
  end

  def has_supplier_return?
    qty_return_to_supplier.to_d.positive?
  end

  def has_discounted?
    qty_discounted_resalable.to_d.positive?
  end

  private

  def total_does_not_exceed_reported
    return unless return_line
    reported = return_line.qty_reported.to_d
    if total_accounted > reported
      errors.add(:base, "QC quantities (#{total_accounted}) exceed qty reported (#{reported})")
    end
  end

  def discount_pct_required_for_discounted_resalable
    if qty_discounted_resalable.to_d.positive? && discount_pct.to_d.zero?
      errors.add(:discount_pct, 'must be set when qty_discounted_resalable > 0')
    end
  end
end
