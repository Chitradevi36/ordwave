# frozen_string_literal: true

# Audit record for each GSTR-1 return that has been generated or exported.
#
# Each row captures a snapshot of what was included in the return:
#   - Section counts (B2B, B2CL, B2CS, CDNR, CDNUR)
#   - Aggregate totals
#   - Validation warnings and errors
#   - Path to the generated JSON file (if downloaded/stored)
#   - Lifecycle status: pending → generating → ready | failed
#
class Gstr1ExportRecord < ApplicationRecord
  STATUSES = %w[pending generating ready failed].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch,       optional: true
  belongs_to :generated_by, class_name: 'User', optional: true

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :gstin,         presence: true
  validates :return_period, presence: true,
                            format: { with: /\A\d{2}\d{4}\z/, message: 'must be MMYYYY' }
  validates :period_from,   presence: true
  validates :period_to,     presence: true
  validates :status,        inclusion: { in: STATUSES }

  validate :period_to_after_period_from

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :for_org,     ->(org) { where(organization: org) }
  scope :ready,       -> { where(status: 'ready') }
  scope :failed,      -> { where(status: 'failed') }
  scope :for_period,  ->(period) { where(return_period: period) }
  scope :recent,      -> { order(created_at: :desc) }

  # ── State-machine helpers ────────────────────────────────────────────────────
  def pending?    = status == 'pending'
  def generating? = status == 'generating'
  def ready?      = status == 'ready'
  def failed?     = status == 'failed'

  def mark_generating!
    update!(status: 'generating')
  end

  def mark_ready!(file_path: nil, checksum: nil, counts: {}, totals: {})
    assign_attributes(
      status:             'ready',
      completed_at:       Time.current,
      file_path:          file_path,
      checksum:           checksum,
      b2b_count:          counts[:b2b]   || 0,
      b2cl_count:         counts[:b2cl]  || 0,
      b2cs_count:         counts[:b2cs]  || 0,
      cdnr_count:         counts[:cdnr]  || 0,
      cdnur_count:        counts[:cdnur] || 0,
      total_invoice_count: counts[:invoices] || 0,
      total_cn_count:      counts[:credit_notes] || 0,
      total_taxable_value: totals[:taxable] || 0,
      total_tax_value:     totals[:tax]     || 0,
      total_invoice_value: totals[:total]   || 0
    )
    save!
  end

  def mark_failed!(message)
    update!(status: 'failed', error_message: message, completed_at: Time.current)
  end

  def store_validation_report!(validation_result)
    update!(
      error_count:       validation_result.error_count,
      warning_count:     validation_result.warning_count,
      validation_report: {
        errors:   validation_result.errors,
        warnings: validation_result.warnings
      }
    )
  end

  private

  def period_to_after_period_from
    return unless period_from && period_to
    errors.add(:period_to, 'must be after period_from') if period_to < period_from
  end
end
