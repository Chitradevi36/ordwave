class Export < ApplicationRecord
  EXPORT_TYPES = %w[orders invoices payments customers inventory beats].freeze
  FORMATS      = %w[csv xlsx].freeze
  STATUSES     = %w[pending processing ready failed].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :requested_by, class_name: "User"

  has_one_attached :file

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :export_type, inclusion: { in: EXPORT_TYPES }
  validates :format,      inclusion: { in: FORMATS }
  validates :status,      inclusion: { in: STATUSES }

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :for_org,  ->(org)  { where(organization: org) }
  scope :recent,   ->       { order(created_at: :desc) }
  scope :ready,    ->       { where(status: "ready") }
  scope :pending,  ->       { where(status: %w[pending processing]) }

  # ── Helpers ─────────────────────────────────────────────────────────────────
  def download_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(file, disposition: "attachment")
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_ready!(row_count:)
    update!(status: "ready", row_count: row_count, completed_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, completed_at: Time.current)
  end
end
