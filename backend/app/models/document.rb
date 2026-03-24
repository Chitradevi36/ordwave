# ── Document Model ────────────────────────────────────────────────────────────
# Stores generated PDF documents with metadata and audit trail

class Document < ApplicationRecord
  # ── Associations ───────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :generated_by_user, class_name: 'User', optional: true

  # ── Validations ────────────────────────────────────────────────────────────────
  validates :organization_id, presence: true
  validates :document_type, presence: true, inclusion: { in: %w[invoice waybill ewaybill delivery_receipt credit_note], message: '%{value} is not a valid document type' }
  validates :filename, presence: true
  validates :status, presence: true, inclusion: { in: %w[generated regenerated archived], message: '%{value} is not a valid status' }
  validates :content, presence: true
  validates :size_bytes, presence: true, numericality: { greater_than: 0 }

  # ── Scopes ─────────────────────────────────────────────────────────────────────
  scope :for_org, ->(org_id) { where(organization_id: org_id) }
  scope :by_type, ->(type) { where(document_type: type) }
  scope :active, -> { where.not(status: 'archived') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_reference, ->(ref_id) { where(reference_id: ref_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # ── Callbacks ──────────────────────────────────────────────────────────────────
  before_save :calculate_file_hash
  before_destroy :validate_not_archived

  # ── Instance Methods ───────────────────────────────────────────────────────────

  # Download document as binary PDF
  def download_data
    content
  end

  # Download document with correct content type
  def to_file
    {
      data: content,
      filename:,
      type: 'application/pdf',
    }
  end

  # Archive document (soft delete for audit trail)
  def archive!
    update(
      status: 'archived',
      archived_at: Time.current,
    )
  end

  # Check if document can be regenerated
  def regeneratable?
    !archived?
  end

  # Get human-readable document type
  def document_type_label
    document_type.humanize.titleize
  end

  # Get file size in human-readable format (KB, MB)
  def size_formatted
    case size_bytes
    when 0...1024
      "#{size_bytes} B"
    when 1024...1024 * 1024
      "#{(size_bytes / 1024.0).round(2)} KB"
    else
      "#{(size_bytes / (1024.0 * 1024)).round(2)} MB"
    end
  end

  # Get generated timestamp from metadata
  def regenerated?
    status == 'regenerated'
  end

  # Get metadata value with fallback
  def get_metadata(key, default = nil)
    metadata&.dig(key) || default
  end

  # ── Class Methods ──────────────────────────────────────────────────────────────

  # Find and download document
  def self.download(document_id)
    doc = find(document_id)
    doc.to_file if doc&.active?
  end

  # Cleanup old archived documents (runs periodically)
  def self.cleanup_archived(days_ago = 90)
    where(status: 'archived')
      .where('archived_at < ?', days_ago.days.ago)
      .delete_all
  end

  # Get document statistics for organization
  def self.stats_for_org(org_id)
    org_docs = for_org(org_id).active

    {
      total_count: org_docs.count,
      by_type: org_docs.group(:document_type).count,
      total_size_mb: org_docs.sum(:size_bytes) / (1024 * 1024),
      created_this_month: org_docs.where('created_at >= ?', 1.month.ago).count,
      average_size_kb: org_docs.average(:size_bytes) / 1024.0,
    }
  end

  private

  # Calculate SHA256 hash of content for deduplication
  def calculate_file_hash
    return if content.blank?

    self.file_hash = Digest::SHA256.hexdigest(content)
  end

  # Prevent deletion of archived documents
  def validate_not_archived
    raise "Cannot delete archived document. Archive date: #{archived_at}" if archived?
  end
end
