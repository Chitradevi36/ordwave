class ReturnLine < ApplicationRecord
  CONDITIONS_REPORTED = %w[resalable damaged expired unknown].freeze
  REASON_CODES        = %w[customer_refused quality_issue expired short_supply wrong_item damaged other].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :return_request, inverse_of: :lines
  belongs_to :product
  belongs_to :sales_order_line, optional: true

  has_one :qc_item, class_name: 'ReturnQcItem', dependent: :destroy, inverse_of: :return_line

  # ── Validations ────────────────────────────────────────────────────────────
  validates :qty_reported,        numericality: { greater_than: 0 }
  validates :qty_accepted,        numericality: { greater_than_or_equal_to: 0 }
  validates :qty_rejected,        numericality: { greater_than_or_equal_to: 0 }
  validates :condition_reported,  inclusion: { in: CONDITIONS_REPORTED }
  validates :reason_code,         inclusion: { in: REASON_CODES }
  validate  :expiry_date_coherence

  # ── Helpers ────────────────────────────────────────────────────────────────
  def qc_done?
    qc_item.present?
  end

  def expired_at_return?
    expiry_date.present? && expiry_date <= return_request.return_date
  end

  def near_expiry?(days_threshold: 30)
    return false unless expiry_date.present?
    expiry_date <= (return_request.return_date + days_threshold.days)
  end

  def effective_unit_price
    unit_price_snapshot.presence ||
      sales_order_line&.unit_price ||
      product.try(:base_price) ||
      0
  end

  def effective_gst_rate
    gst_rate_snapshot.presence ||
      sales_order_line&.gst_rate ||
      product.try(:gst_rate) ||
      0
  end

  def effective_hsn_code
    hsn_code_snapshot.presence ||
      sales_order_line&.hsn_code ||
      product.try(:hsn_code)
  end

  private

  def expiry_date_coherence
    return unless manufacture_date.present? && expiry_date.present?
    errors.add(:expiry_date, 'must be after manufacture date') if expiry_date <= manufacture_date
  end
end
