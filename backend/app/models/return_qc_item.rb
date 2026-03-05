class ReturnQcItem < ApplicationRecord
  CONDITIONS_FINAL = %w[resalable damaged expired mixed].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :return_line,  inverse_of: :qc_item
  belongs_to :qc_by, class_name: 'User'

  # ── Validations ────────────────────────────────────────────────────────────
  validates :condition_final, inclusion: { in: CONDITIONS_FINAL }
  validates :qc_at,           presence: true
  validates :qty_resalable,   numericality: { greater_than_or_equal_to: 0 }
  validates :qty_damaged,     numericality: { greater_than_or_equal_to: 0 }
  validates :qty_expired,     numericality: { greater_than_or_equal_to: 0 }

  validate :total_does_not_exceed_reported

  # ── Helpers ────────────────────────────────────────────────────────────────
  def total_accounted
    qty_resalable.to_d + qty_damaged.to_d + qty_expired.to_d
  end

  def total_restorable
    qty_resalable.to_d
  end

  private

  def total_does_not_exceed_reported
    return unless return_line
    reported = return_line.qty_reported.to_d
    if total_accounted > reported
      errors.add(:base, "QC quantities (#{total_accounted}) exceed qty reported (#{reported})")
    end
  end
end
