class VisitLog < ApplicationRecord
  STATUSES   = %w[planned checked_in completed skipped].freeze
  SKIP_CODES = %w[shop_closed customer_request out_of_area other].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :sales_rep,     class_name: 'User'
  belongs_to :customer
  belongs_to :route,         optional: true
  belongs_to :beat_schedule, optional: true

  # ── Validations ──────────────────────────────────────────────────────────
  validates :visit_date,    presence: true
  validates :visit_status,  presence: true, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validates :skip_reason_code, inclusion: { in: SKIP_CODES, allow_blank: true }

  validate :checkout_after_checkin, if: -> { checkin_at.present? && checkout_at.present? }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :for_rep,      ->(uid) { where(sales_rep_id: uid) }
  scope :for_date,     ->(d)   { where(visit_date: d) }
  scope :for_customer, ->(cid) { where(customer_id: cid) }
  scope :planned,      -> { where(visit_status: 'planned') }
  scope :checked_in,   -> { where(visit_status: 'checked_in') }
  scope :completed,    -> { where(visit_status: 'completed') }
  scope :skipped,      -> { where(visit_status: 'skipped') }

  # ── Helpers ──────────────────────────────────────────────────────────────
  def duration_minutes
    return nil unless checkin_at.present? && checkout_at.present?

    ((checkout_at - checkin_at) / 60).round
  end

  private

  def checkout_after_checkin
    errors.add(:checkout_at, 'must be after check-in time') if checkout_at <= checkin_at
  end
end
