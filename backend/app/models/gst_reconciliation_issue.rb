# frozen_string_literal: true

# GstReconciliationIssue represents a single GST compliance problem detected
# during GSTR-2B matching, GSTR-1 generation, or periodic audits.
#
# Issue types classify what went wrong.
# Severity drives urgency: blocking → must resolve before filing; high → should resolve.
# Status lifecycle: open ──► acknowledged ──► resolved / ignored
#
class GstReconciliationIssue < ApplicationRecord
  ISSUE_TYPES = %w[
    missing_in_2b missing_in_books
    tax_mismatch date_mismatch gstin_mismatch invoice_value_mismatch
    duplicate_invoice invalid_hsn missing_gstin
    reverse_charge_mismatch itc_risk
  ].freeze

  SEVERITIES = %w[blocking high medium low].freeze

  STATUSES = %w[open acknowledged resolved ignored].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch,            optional: true
  belongs_to :financial_year,    optional: true
  belongs_to :gst_return_period, optional: true
  belongs_to :gst2b_import,      optional: true
  belongs_to :resolved_by,       class_name: 'User', optional: true

  # Polymorphic: the primary document that has the issue (e.g. SalesInvoice, PurchaseInvoice)
  belongs_to :source,      polymorphic: true, optional: true
  # Polymorphic: the counterpart document (e.g. the portal record, the 2B line)
  belongs_to :counterpart, polymorphic: true, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :issue_type, presence: true, inclusion: { in: ISSUE_TYPES }
  validates :severity,   presence: true, inclusion: { in: SEVERITIES }
  validates :status,     inclusion: { in: STATUSES }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,        ->(org)    { where(organization: org) }
  scope :for_period,     ->(p)      { where(gst_return_period: p) }
  scope :for_fy,         ->(fy)     { where(financial_year: fy) }
  scope :for_supplier,   ->(gstin)  { where(supplier_gstin: gstin) }
  scope :open,           ->         { where(status: 'open') }
  scope :blocking,       ->         { where(severity: 'blocking') }
  scope :high_or_above,  ->         { where(severity: %w[blocking high]) }
  scope :unresolved,     ->         { where(status: %w[open acknowledged]) }
  scope :resolved,       ->         { where(status: %w[resolved ignored]) }
  scope :by_severity,    ->         { order(Arel.sql("CASE severity WHEN 'blocking' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END")) }
  scope :recent,         ->         { order(created_at: :desc) }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }
  def unresolved?; status.in?(%w[open acknowledged]); end
  def blocking?;   severity == 'blocking'; end

  # ── Lifecycle transitions ─────────────────────────────────────────────────────

  def acknowledge!(by_user:)
    update!(status: 'acknowledged')
    log_action!('acknowledge_issue', by_user)
  end

  def resolve!(by_user:, notes: nil)
    update!(
      status:           'resolved',
      resolution_notes: notes,
      resolved_by:      by_user,
      resolved_at:      Time.current
    )
    log_action!('resolve_issue', by_user)
  end

  def ignore!(by_user:, reason: nil)
    update!(
      status:           'ignored',
      resolution_notes: reason,
      resolved_by:      by_user,
      resolved_at:      Time.current
    )
    log_action!('ignore_issue', by_user)
  end

  def reopen!(by_user:)
    update!(status: 'open', resolved_by: nil, resolved_at: nil, resolution_notes: nil)
    log_action!('reopen_issue', by_user)
  end

  # ── Display helpers ───────────────────────────────────────────────────────────

  def summary
    case issue_type
    when 'missing_in_2b'
      "Invoice #{invoice_number} not found in GSTR-2B (supplier: #{supplier_gstin})"
    when 'missing_in_books'
      "Invoice #{invoice_number} in 2B but missing from purchase books (supplier: #{supplier_gstin})"
    when 'tax_mismatch'
      diff = difference_amount.present? ? " (diff: ₹#{difference_amount})" : ''
      "Tax mismatch on #{invoice_number}#{diff}"
    when 'gstin_mismatch'
      "GSTIN mismatch on #{invoice_number}: #{supplier_gstin}"
    when 'itc_risk'
      "ITC risk on #{invoice_number} — #{supplier_gstin}"
    else
      issue_type.humanize
    end
  end

  def difference_formatted
    return nil unless difference_amount.present?
    '₹ ' + format('%.2f', difference_amount.abs)
  end

  private

  def log_action!(action, user)
    return unless user.present?
    AuditLog.create!(
      organization:  organization,
      actor:         user,
      auditable:     self,
      action:        action,
      changes_data:  { issue_type: issue_type, status: status }
    )
  rescue StandardError => e
    Rails.logger.warn("GstReconciliationIssue audit log failed: #{e.message}")
  end
end
