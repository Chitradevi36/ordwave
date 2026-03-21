# frozen_string_literal: true

class RescheduleDelivery < ApplicationRecord
  STATUSES = %w[pending rescheduled delivered cancelled escalated].freeze
  FAILURE_CODES = TripStop::EXCEPTION_CODES.freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :trip_stop
  belongs_to :sales_order
  belongs_to :customer, optional: true
  belongs_to :new_trip_stop, class_name: 'TripStop', optional: true

  # ── Validations ──────────────────────────────────────────────────────────
  validates :original_date, presence: true
  validates :failure_code, inclusion: { in: FAILURE_CODES }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempt_count, numericality: { greater_than_or_equal_to: 1 }
  validates :max_attempts, numericality: { greater_than_or_equal_to: 1 }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :for_org, ->(org) { where(organization: org) }
  scope :pending, -> { where(status: 'pending') }
  scope :rescheduled, -> { where(status: 'rescheduled') }
  scope :overdue, -> { where('next_retry_date < ?', Date.current).where(status: %w[pending rescheduled]) }
  scope :by_failure_code, ->(code) { where(failure_code: code) }
  scope :for_customer, ->(c) { where(customer: c) }

  # ── Callbacks ────────────────────────────────────────────────────────────
  before_validation :ensure_organization_id

  # ── Status helpers ────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def should_escalate?
    pending? && attempt_count >= max_attempts
  end

  def days_until_retry
    return nil if next_retry_date.blank?
    (next_retry_date - Date.current).to_i
  end

  def is_overdue?
    next_retry_date.present? && next_retry_date < Date.current && (pending? || rescheduled?)
  end

  private

  def ensure_organization_id
    self.organization_id ||= trip_stop&.delivery_trip&.organization_id
  end
end
