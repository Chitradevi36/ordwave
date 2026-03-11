# frozen_string_literal: true

# FinancialYear is the canonical fiscal period record for an organization.
#
# India default: April 1 → March 31
# All GST return periods and fiscal reports derive from a FinancialYear.
#
# Status lifecycle:
#   open ──► locked ──► closed ──► archived
#
class FinancialYear < ApplicationRecord
  STATUSES = %w[open locked closed archived].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :closed_by, class_name: 'User', optional: true

  has_many :gst_return_periods, dependent: :destroy
  has_many :gst2b_imports,      dependent: :destroy
  has_many :gst_reconciliation_issues, dependent: :destroy

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :code,           presence: true,
                             uniqueness: { scope: :organization_id }
  validates :label,          presence: true
  validates :start_date,     presence: true
  validates :end_date,       presence: true
  validates :status,         inclusion: { in: STATUSES }
  validates :starts_on_month, inclusion: { in: 1..12 }
  validates :starts_on_day,   inclusion: { in: 1..31 }
  validate  :end_date_after_start_date

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,    ->(org) { where(organization: org) }
  scope :open,       -> { where(status: 'open') }
  scope :current,    -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :for_date,   ->(d)   { where('start_date <= ? AND end_date >= ?', d, d) }
  scope :closed,     -> { where(status: %w[closed archived]) }
  scope :recent,     -> { order(start_date: :desc) }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def gst_locked?;   gst_locked_at.present?; end
  def books_locked?; books_locked_at.present?; end

  # ── Date helpers ──────────────────────────────────────────────────────────────

  def includes_date?(date)
    date.to_date >= start_date && date.to_date <= end_date
  end

  # Returns fiscal month index 1–12 where 1 = starts_on_month (default April)
  def fiscal_month_for(date)
    ((date.month - starts_on_month) % 12) + 1
  end

  def fiscal_quarter_for(date)
    ((fiscal_month_for(date) - 1) / 3) + 1
  end

  # Returns array of [calendar_month, calendar_year] for all 12 months of FY
  def calendar_months
    (0..11).map do |i|
      d = start_date >> i
      { month: d.month, year: d.year }
    end
  end

  def period_start_for(calendar_month, calendar_year)
    Date.new(calendar_year, calendar_month, 1)
  end

  def period_end_for(calendar_month, calendar_year)
    Date.new(calendar_year, calendar_month, 1).end_of_month
  end

  # ── Navigation ────────────────────────────────────────────────────────────────
  def previous_financial_year
    self.class.find_by(
      organization_id: organization_id,
      start_date: start_date - 1.year
    )
  end

  def next_financial_year
    self.class.find_by(
      organization_id: organization_id,
      start_date: start_date + 1.year
    )
  end

  # ── Lifecycle transitions ────────────────────────────────────────────────────

  def lock_books!(by_user: nil)
    update!(books_locked_at: Time.current, status: 'locked')
    log_action!('lock_books', by_user)
  end

  def lock_gst!(by_user: nil)
    update!(gst_locked_at: Time.current)
    log_action!('lock_gst', by_user)
  end

  def close_year!(by_user: nil)
    update!(closed_at: Time.current, closed_by: by_user, status: 'closed')
    log_action!('close_year', by_user)
  end

  def archive!(by_user: nil)
    update!(status: 'archived')
    log_action!('archive', by_user)
  end

  # ── Closing checklist ────────────────────────────────────────────────────────

  def closing_checklist
    gstr1_unfiled  = gst_return_periods.where(return_type: 'gstr1').
                       where.not(status: 'filed').count
    gstr3b_unfiled = gst_return_periods.where(return_type: 'gstr3b').
                       where.not(status: 'filed').count
    open_issues    = gst_reconciliation_issues.where(status: 'open').count

    ready = gstr1_unfiled.zero? && gstr3b_unfiled.zero? && open_issues.zero?

    {
      ready_to_close: ready,
      checklist: [
        { item: 'all_gstr1_periods_filed',     status: gstr1_unfiled.zero?  ? 'pass' : 'fail', count: gstr1_unfiled },
        { item: 'all_gstr3b_periods_filed',    status: gstr3b_unfiled.zero? ? 'pass' : 'fail', count: gstr3b_unfiled },
        { item: 'open_reconciliation_issues',  status: open_issues.zero?    ? 'pass' : 'fail', count: open_issues }
      ]
    }
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    errors.add(:end_date, 'must be after start_date') if end_date <= start_date
  end

  def log_action!(action, user)
    return unless user.present?
    AuditLog.create!(
      organization:  organization,
      actor:         user,
      auditable:     self,
      action:        action,
      changes_data:  {}
    )
  rescue StandardError => e
    Rails.logger.warn("FinancialYear audit log failed: #{e.message}")
  end
end
