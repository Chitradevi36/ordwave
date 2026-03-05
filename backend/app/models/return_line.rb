class ReturnLine < ApplicationRecord
  CONDITIONS_REPORTED = %w[resalable damaged expired unknown].freeze
  REASON_CODES        = %w[customer_refused quality_issue expired short_supply other].freeze

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

  # ── Helpers ────────────────────────────────────────────────────────────────
  def qc_done?
    qc_item.present?
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
end
