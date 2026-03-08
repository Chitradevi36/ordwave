class AccountingExportFile < ApplicationRecord
  include AccountingTenantValidatable

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :organization
  belongs_to :accounting_integration
  belongs_to :generated_by, class_name: "User", optional: true
  # Branch table confirmed to exist in this app
  belongs_to :branch, optional: true

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum status: {
    generating: "generating",
    ready:      "ready",
    failed:     "failed"
  }, _prefix: :status

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :organization,           presence: true
  validates :accounting_integration, presence: true
  validates :provider,               presence: true
  validates :export_type,            presence: true
  validates :status,                 presence: true

  validate :validate_date_range, if: -> { date_from.present? && date_to.present? }

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :inherit_provider_from_integration
  before_validation :normalize_export_type

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :generating,      -> { where(status: "generating") }
  scope :ready,           -> { where(status: "ready") }
  scope :failed,          -> { where(status: "failed") }
  scope :recent_first,    -> { order(created_at: :desc) }
  scope :for_provider,    ->(prov) { where(provider: prov) }
  scope :for_export_type, ->(type) { where(export_type: type) }
  scope :within_range,    ->(from, to) { where("date_from >= ? AND date_to <= ?", from, to) }

  # ---------------------------------------------------------------------------
  # Status helpers
  # ---------------------------------------------------------------------------
  def ready?      = status_ready?
  def failed?     = status_failed?
  def generating? = status_generating?

  # A file is downloadable when it is ready and a path has been recorded
  def downloadable?
    status_ready? && file_path.present?
  end

  # ---------------------------------------------------------------------------
  # State transition helpers
  # ---------------------------------------------------------------------------
  def mark_ready!(file_path:)
    update!(status: "ready", file_path: file_path)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message)
  end

  # ---------------------------------------------------------------------------
  # Display / utility helpers
  # ---------------------------------------------------------------------------
  def date_range_label
    return "All dates" if date_from.blank? && date_to.blank?
    return "From #{date_from}" if date_to.blank?
    return "Until #{date_to}" if date_from.blank?
    "#{date_from} – #{date_to}"
  end

  # Provides a stable, human-readable base string suitable for filenames
  # e.g. "tally_invoices_2026-01-01_2026-01-31"
  def filename_base
    parts = [provider, export_type]
    parts << date_from.to_s  if date_from.present?
    parts << date_to.to_s    if date_to.present?
    parts.join("_")
  end

  def provider_matches_integration?
    return true if accounting_integration.blank?
    provider == accounting_integration.provider
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  private

  def validate_date_range
    if date_to < date_from
      errors.add(:date_to, "must be on or after date_from")
    end
  end

  def inherit_provider_from_integration
    return if accounting_integration.blank?
    self.provider     = accounting_integration.provider     if provider.blank?
    self.organization = accounting_integration.organization if organization.blank?
  end

  def normalize_export_type
    self.export_type = export_type.to_s.strip.downcase if export_type.present?
  end
end
