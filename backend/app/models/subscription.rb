# app/models/subscription.rb
#
# Tracks a billing subscription for an Organization.
# One organization may have multiple subscription records over time (history),
# but only one record with status "active" at any given time.
#
# Status lifecycle:
#   pending     → created locally, awaiting Razorpay checkout
#   active      → payment confirmed, full access granted
#   past_due    → payment failed, grace period in effect
#   cancelled   → cancelled (expires at ends_at)
#   expired     → period ended, no renewal
#
class Subscription < ApplicationRecord
  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  has_many   :billing_events, dependent: :destroy

  # ── Enums / Constants ────────────────────────────────────────────────────────
  STATUSES = %w[pending active past_due cancelled expired].freeze
  PLANS    = Billing::PlanCatalog::PLANS

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :plan,   presence: true, inclusion: { in: PLANS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :active,    -> { where(status: "active") }
  scope :paid,      -> { where.not(plan: "free") }
  scope :current,   -> { where(status: %w[active past_due]).order(created_at: :desc) }

  # ── Callbacks ────────────────────────────────────────────────────────────────
  before_validation :set_defaults, on: :create

  # ── Instance helpers ─────────────────────────────────────────────────────────

  def active?
    status == "active"
  end

  def past_due?
    status == "past_due"
  end

  def cancelled?
    status == "cancelled"
  end

  def expired?
    status == "expired"
  end

  def free?
    plan == "free"
  end

  def paid?
    !free?
  end

  def in_grace_period?
    past_due? && ends_at && ends_at > Time.current
  end

  def activate!(period_start: Time.current, period_end: 1.month.from_now, razorpay_subscription_id: nil)
    update!(
      status:                  "active",
      current_period_start:    period_start,
      current_period_end:      period_end,
      razorpay_subscription_id: razorpay_subscription_id || self.razorpay_subscription_id
    )
  end

  def mark_past_due!(grace_ends_at: 7.days.from_now)
    update!(status: "past_due", ends_at: grace_ends_at)
  end

  def cancel!(at: Time.current)
    update!(status: "cancelled", cancelled_at: at, ends_at: current_period_end || at)
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.quantity ||= 1
    self.metadata ||= {}
  end
end
