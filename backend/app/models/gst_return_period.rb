# frozen_string_literal: true

# GstReturnPeriod tracks the filing lifecycle for one monthly GST return.
#
# Each combination of (organization, branch, financial_year, month, year, return_type)
# is unique. The period drives snapshot generation, period locking, and filing status.
#
# Status lifecycle:
#   draft ──► generated ──► reviewed ──► locked ──► filed
#                               └──────────────────────────► (reopened back to generated)
#
# Return types: gstr1 / gstr3b / gstr2b_import
#
class GstReturnPeriod < ApplicationRecord
  STATUSES     = %w[draft generated reviewed locked filed].freeze
  RETURN_TYPES = %w[gstr1 gstr3b gstr2b_import].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :financial_year
  belongs_to :branch,       optional: true
  belongs_to :filed_by,     class_name: 'User', optional: true
  belongs_to :locked_by,    class_name: 'User', optional: true
  belongs_to :reviewed_by,  class_name: 'User', optional: true

  has_many :gst_return_snapshots, dependent: :destroy
  has_many :gst_reconciliation_issues, dependent: :nullify

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :month,          presence: true, inclusion: { in: 1..12 }
  validates :year,           presence: true
  validates :return_type,    presence: true, inclusion: { in: RETURN_TYPES }
  validates :status,         inclusion: { in: STATUSES }
  validates :period_start_on, presence: true
  validates :period_end_on,   presence: true
  validate  :period_within_financial_year
  validate  :period_end_after_start

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,         ->(org) { where(organization: org) }
  scope :for_type,        ->(t)   { where(return_type: t) }
  scope :for_month_year,  ->(m, y){ where(month: m, year: y) }
  scope :filed,           -> { where(status: 'filed') }
  scope :locked,          -> { where(status: %w[locked filed]) }
  scope :gstr1,           -> { where(return_type: 'gstr1') }
  scope :gstr3b,          -> { where(return_type: 'gstr3b') }
  scope :recent,          -> { order(year: :desc, month: :desc) }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def locked_or_filed?; status.in?(%w[locked filed]); end

  def reopenable?
    status.in?(%w[locked filed])
  end

  # ── Display helpers ───────────────────────────────────────────────────────────

  def display_name
    month_name = Date::MONTHNAMES[month]
    "#{month_name} #{year} — #{return_type.upcase}"
  end

  def filing_period_code
    # MMYYYY format as required by GST portal
    "#{month.to_s.rjust(2, '0')}#{year}"
  end

  def month_name
    Date::MONTHNAMES[month]
  end

  # ── Snapshot helpers ──────────────────────────────────────────────────────────

  def latest_snapshot
    gst_return_snapshots.order(version_number: :desc).first
  end

  def filed_snapshot
    gst_return_snapshots.find_by(is_filed: true)
  end

  def current_version
    latest_snapshot&.version_number || 0
  end

  # ── Lifecycle transitions ─────────────────────────────────────────────────────

  def mark_generated!(source_hash: nil, error_count: 0, warning_count: 0)
    update!(
      status:        'generated',
      generated_at:  Time.current,
      source_hash:   source_hash,
      error_count:   error_count,
      warning_count: warning_count
    )
  end

  def mark_reviewed!(by_user:)
    update!(status: 'reviewed', reviewed_by: by_user)
  end

  def lock!(by_user:)
    raise "Period must be reviewed before locking" unless status.in?(%w[generated reviewed])
    update!(status: 'locked', locked_at: Time.current, locked_by: by_user)
    log_action!('lock_period', by_user)
  end

  def file!(by_user:, notes: nil)
    raise "Period must be locked before filing" unless locked?
    # Freeze the latest snapshot
    gst_return_snapshots.order(version_number: :desc).first&.update!(is_filed: true)
    update!(status: 'filed', filed_at: Time.current, filed_by: by_user,
            filing_notes: notes)
    log_action!('file_return', by_user)
  end

  def reopen!(by_user:, reason:)
    raise "Period is not reopenable" unless reopenable?
    previous_status = status
    update!(status: 'generated', filed_at: nil, locked_at: nil)
    # Unfreeze filed snapshot so new generation is not confused
    gst_return_snapshots.where(is_filed: true).update_all(is_filed: false)
    log_action!('reopen_period', by_user, { reason: reason, from_status: previous_status })
  end

  private

  def period_within_financial_year
    return unless financial_year && period_start_on && period_end_on
    unless financial_year.includes_date?(period_start_on) &&
           financial_year.includes_date?(period_end_on)
      errors.add(:base, "Period dates must fall within the linked financial year")
    end
  end

  def period_end_after_start
    return unless period_start_on && period_end_on
    errors.add(:period_end_on, 'must be after period_start_on') if period_end_on < period_start_on
  end

  def log_action!(action, user, extra = {})
    return unless user.present?
    AuditLog.create!(
      organization:  organization,
      actor:         user,
      auditable:     self,
      action:        action,
      changes_data:  { return_type: return_type, month: month, year: year }.merge(extra)
    )
  rescue StandardError => e
    Rails.logger.warn("GstReturnPeriod audit log failed: #{e.message}")
  end
end
