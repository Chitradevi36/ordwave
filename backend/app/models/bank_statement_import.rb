# frozen_string_literal: true

class BankStatementImport < ApplicationRecord
  SOURCE_TYPES = %w[csv xlsx pdf manual api].freeze
  STATUSES     = %w[uploaded processing completed failed].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :bank_account
  belongs_to :uploaded_by, class_name: "User", optional: true

  has_many :bank_transactions, dependent: :nullify
  has_one_attached :csv_file

  # ── Validations ──────────────────────────────────────────────────────────
  validates :file_name,    presence: true
  validates :source_type,  inclusion: { in: SOURCE_TYPES }
  validates :status,       inclusion: { in: STATUSES }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :for_org,   ->(org) { where(organization: org) }
  scope :recent,    ->      { order(created_at: :desc) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  # ── State transitions ─────────────────────────────────────────────────────
  def start_processing!
    update!(status: "processing")
  end

  def mark_completed!(new_rows:, duplicates:, failed:, total:)
    update!(
      status:               "completed",
      rows_count:           total,
      new_rows_count:       new_rows,
      duplicate_rows_count: duplicates,
      failed_rows_count:    failed,
      processed_rows_count: new_rows + duplicates + failed
    )
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message)
  end

  # ── Summary hash for API ──────────────────────────────────────────────────
  def summary
    {
      total:      rows_count,
      new:        new_rows_count,
      duplicates: duplicate_rows_count,
      failed:     failed_rows_count,
      processed:  processed_rows_count
    }
  end
end
