class AccountingSyncRecord < ApplicationRecord
  include AccountingTenantValidatable

  # ---------------------------------------------------------------------------
  # Retry policy: max attempts per priority
  # ---------------------------------------------------------------------------
  MAX_RETRIES = {
    "high"   => 3,
    "medium" => 3,
    "low"    => 2
  }.freeze

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :organization
  belongs_to :accounting_integration

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum direction: {
    outbound: "outbound"
  }, _prefix: false

  enum status: {
    pending:    "pending",
    processing: "processing",
    success:    "success",
    failed:     "failed",
    retrying:   "retrying",
    skipped:    "skipped"
  }, _prefix: :status

  enum priority: {
    high:   "high",
    medium: "medium",
    low:    "low"
  }, _prefix: :priority

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :organization,          presence: true
  validates :accounting_integration, presence: true
  validates :entity_type,           presence: true
  validates :entity_id,             presence: true
  validates :entity_version,        presence: true
  validates :event_type,            presence: true
  validates :provider,              presence: true
  validates :direction,             presence: true
  validates :status,                presence: true
  validates :priority,              presence: true
  validates :idempotency_key,       presence: true,
                                    uniqueness: { scope: :provider }
  validates :attempt_count,         numericality: { greater_than_or_equal_to: 0 }

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :inherit_from_integration

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :pending,             -> { where(status: "pending") }
  scope :processing,          -> { where(status: "processing") }
  scope :successful,          -> { where(status: "success") }
  scope :failed,              -> { where(status: "failed") }
  scope :retryable,           -> { where(status: %w[failed retrying]) }
  scope :for_provider,        ->(prov) { where(provider: prov) }
  scope :for_entity,          ->(entity) { where(entity_type: entity.class.name, entity_id: entity.id) }
  scope :recent_first,        -> { order(created_at: :desc) }
  scope :oldest_first,        -> { order(created_at: :asc) }
  scope :high_priority_first, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END")) }
  scope :queue_order,         -> { where(status: %w[pending retrying]).order(Arel.sql("CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END"), created_at: :asc) }
  scope :for_dashboard,       -> { where(status: %w[pending processing failed retrying]).recent_first }
  scope :stale_processing,    -> { where(status: "processing").where("last_attempted_at < ?", 10.minutes.ago) }
  scope :attempted,           -> { where("attempt_count > 0") }
  scope :not_succeeded,       -> { where.not(status: %w[success skipped]) }

  # ---------------------------------------------------------------------------
  # Predicate helpers
  # (status_ prefix from enum; define plain aliases for readability)
  # ---------------------------------------------------------------------------
  def success?    = status_success?
  def failed?     = status_failed?
  def pending?    = status_pending?
  def processing? = status_processing?
  def retrying?   = status_retrying?
  def skipped?    = status_skipped?
  def done?       = status_success? || status_skipped?
  def high_priority? = priority_high?

  def retryable?
    (status_failed? || status_retrying?) && attempts_remaining > 0
  end

  # ---------------------------------------------------------------------------
  # State transition helpers
  # ---------------------------------------------------------------------------
  def mark_processing!
    update!(status: "processing", last_attempted_at: Time.current)
  end

  def mark_success!(external_reference: nil, response_body: nil)
    attrs = { status: "success", succeeded_at: Time.current }
    attrs[:external_reference] = external_reference if external_reference.present?
    attrs[:response_body]      = response_body      if response_body.present?
    update!(attrs)
  end

  def mark_failed!(message:, response_body: nil)
    attrs = { status: "failed", error_message: message }
    attrs[:response_body] = response_body if response_body.present?
    update!(attrs)
  end

  def mark_retrying!(message: nil)
    attrs = { status: "retrying" }
    attrs[:error_message] = message if message.present?
    update!(attrs)
  end

  def increment_attempt!
    update_columns(attempt_count: attempt_count + 1, last_attempted_at: Time.current)
  end

  def touch_attempted!
    update_column(:last_attempted_at, Time.current)
  end

  # ---------------------------------------------------------------------------
  # Retry policy helpers
  # ---------------------------------------------------------------------------
  def max_retries_for_priority
    MAX_RETRIES.fetch(priority.to_s, 2)
  end

  def attempts_remaining
    [max_retries_for_priority - attempt_count, 0].max
  end

  # ---------------------------------------------------------------------------
  # Display helpers
  # ---------------------------------------------------------------------------
  def entity_reference
    "#{entity_type}##{entity_id}"
  end

  def provider_matches_integration?
    return true if accounting_integration.blank?
    provider == accounting_integration.provider
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  private

  # Auto-populate provider and organization from the integration if not set.
  # Keeps callers clean — they only need to provide accounting_integration.
  def inherit_from_integration
    return if accounting_integration.blank?

    self.provider     = accounting_integration.provider     if provider.blank?
    self.organization = accounting_integration.organization if organization.blank?
  end
end
