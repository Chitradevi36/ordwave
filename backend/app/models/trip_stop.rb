class TripStop < ApplicationRecord
  STATUSES = %w[pending delivered partial_delivery failed skipped].freeze

  EXCEPTION_CODES = %w[
    customer_not_available
    address_not_found
    refused_by_customer
    damaged_goods
    payment_not_ready
    vehicle_breakdown
    other
  ].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :delivery_trip
  belongs_to :sales_order

  has_one    :proof,   class_name: 'DeliveryProof', dependent: :destroy
  has_many   :returns, class_name: 'ReturnRecord',  dependent: :destroy
  has_many   :return_requests, ->(s) { where(source_type: 'delivery', source_id: s.id) }, class_name: 'ReturnRequest', primary_key: :id, foreign_key: :source_id

  # ── Validations ──────────────────────────────────────────────────────────
  validates :sequence,     numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status,       inclusion: { in: STATUSES }
  validates :exception_code, inclusion: { in: EXCEPTION_CODES }, allow_blank: true

  validate :sales_order_approved_or_dispatched, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :not_deleted,    -> { where(deleted_at: nil) }
  scope :by_status,      ->(s) { where(status: s) }
  scope :ordered,        -> { order(:sequence) }
  scope :with_exception, -> { where.not(exception_code: [nil, '']) }

  # ── Status helpers ────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def completed? = delivered? || partial_delivery? || failed? || skipped?

  private

  def sales_order_approved_or_dispatched
    return unless sales_order
    unless %w[approved dispatched].include?(sales_order.status)
      errors.add(:sales_order, 'must be approved or dispatched to add to a trip')
    end
  end
end
