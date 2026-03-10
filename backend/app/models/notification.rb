# frozen_string_literal: true

class Notification < ApplicationRecord
  TYPES = %w[
    order_submitted order_approved order_rejected order_held
    credit_blocked delivery_completed delivery_failed
    payment_confirmed payment_reversed
    stock_low transfer_dispatched transfer_received
    limit_change_requested limit_change_decided
    return_submitted credit_note_issued
    beat_assigned invoice_generated trip_assigned
  ].freeze

  SEVERITIES = %w[low medium high].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :user                                          # recipient
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :notification_type, inclusion: { in: TYPES }
  validates :title,             presence: true
  validates :severity,          inclusion: { in: SEVERITIES }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :unread,         -> { where(read_at: nil) }
  scope :not_dismissed,  -> { where(dismissed_at: nil) }
  scope :recent,         -> { order(created_at: :desc).limit(50) }
  scope :by_type,        ->(type)     { where(notification_type: type) }
  scope :high_priority,  ->           { where(severity: 'high') }
  scope :for_user,       ->(uid)      { where(user_id: uid) }
  scope :for_org,        ->(org_id)   { where(organization_id: org_id) }

  # ── Instance helpers ─────────────────────────────────────────────────────────
  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def dismiss!
    update!(dismissed_at: Time.current)
  end
end
