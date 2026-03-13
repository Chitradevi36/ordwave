# app/models/billing_event.rb
#
# Immutable log of every billing event (webhook or internal).
# The `razorpay_event_id` column is unique — duplicate webhook deliveries are
# safely squashed by attempting to find-or-create on that column.
#
class BillingEvent < ApplicationRecord
  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :subscription, optional: true

  # ── Constants ────────────────────────────────────────────────────────────────
  EVENT_TYPES = %w[
    subscription.created
    subscription.activated
    subscription.charged
    subscription.pending
    subscription.halted
    subscription.cancelled
    subscription.completed
    subscription.updated
    payment.failed
    payment.captured
    refund.created
    internal.free_plan_activated
    internal.plan_changed
    internal.trial_expired
  ].freeze

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :event_type, presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :processed, -> { where.not(processed_at: nil) }
  scope :for_type,  ->(type) { where(event_type: type) }
  scope :recent,    -> { order(created_at: :desc) }

  # ── Class helpers ─────────────────────────────────────────────────────────────

  # Find existing event by razorpay_event_id (idempotency) or create new one.
  # Yields the event to the block only if newly created.
  def self.find_or_create_for_webhook(organization:, subscription: nil, event_type:, razorpay_event_id:, payload: {})
    event = find_or_initialize_by(razorpay_event_id: razorpay_event_id)
    return event if event.persisted?   # already processed — skip

    event.assign_attributes(
      organization:        organization,
      subscription:        subscription,
      event_type:          event_type,
      payload:             payload
    )
    event.save!
    yield event if block_given?
    event
  end

  # Record an internal (non-Razorpay) event, e.g. free plan activation.
  def self.record_internal!(organization:, event_type:, subscription: nil, payload: {})
    create!(
      organization: organization,
      subscription: subscription,
      event_type:   event_type,
      payload:      payload,
      processed_at: Time.current
    )
  end

  # ── Instance helpers ─────────────────────────────────────────────────────────

  def processed?
    processed_at.present?
  end

  def mark_processed!
    update!(processed_at: Time.current)
  end
end
