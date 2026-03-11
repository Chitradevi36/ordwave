# frozen_string_literal: true

# Gst2bImport represents one uploaded GSTR-2B JSON file from the GST portal.
#
# Lifecycle:
#   uploaded ──► parsing ──► parsed ──► matching ──► completed
#                                                 └──► failed (at any step)
#
# Each import belongs to a branch's GST registration (GSTIN) for a given month/year.
# After parsing, lines are created in Gst2bImportLine.
# After matching, each line is reconciled against PurchaseInvoices in books.
#
class Gst2bImport < ApplicationRecord
  STATUSES = %w[uploaded parsing parsed matching completed failed].freeze
  SOURCE_TYPES = %w[json csv api_pull].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :financial_year, optional: true
  belongs_to :branch,         optional: true
  belongs_to :imported_by,    class_name: 'User', optional: true

  has_many :gst2b_import_lines, dependent: :destroy
  has_many :gst_reconciliation_issues, dependent: :nullify

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :gstin,          presence: true,
                             format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/,
                                       message: 'must be a valid 15-character GSTIN' }
  validates :month,          presence: true, inclusion: { in: 1..12 }
  validates :year,           presence: true
  validates :import_status,  inclusion: { in: STATUSES }
  validates :source_type,    inclusion: { in: SOURCE_TYPES }, allow_nil: true

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org,          ->(org) { where(organization: org) }
  scope :for_gstin,        ->(g)   { where(gstin: g) }
  scope :for_month_year,   ->(m, y){ where(month: m, year: y) }
  scope :completed,        ->      { where(import_status: 'completed') }
  scope :failed,           ->      { where(import_status: 'failed') }
  scope :recent,           ->      { order(created_at: :desc) }
  scope :with_lines,       ->      { includes(:gst2b_import_lines) }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { import_status == s } }

  # ── Display helpers ───────────────────────────────────────────────────────────

  def month_name
    Date::MONTHNAMES[month]
  end

  def period_label
    "#{month_name} #{year}"
  end

  def match_rate
    return 0 if total_rows.to_i.zero?
    ((matched_rows.to_f / total_rows) * 100).round(1)
  end

  # ── Derived stats ─────────────────────────────────────────────────────────────

  def recalculate_stats!
    lines  = gst2b_import_lines
    totals = lines.group(:match_status).count
    update!(
      total_rows:     lines.count,
      matched_rows:   totals['matched'].to_i,
      unmatched_rows: lines.where.not(match_status: %w[matched ignored]).count,
      error_rows:     0
    )
  end

  # ── Lifecycle transitions ─────────────────────────────────────────────────────

  def mark_parsing!
    update!(import_status: 'parsing')
  end

  def mark_parsed!(row_count:)
    update!(import_status: 'parsed', total_rows: row_count)
  end

  def mark_matching!
    update!(import_status: 'matching')
  end

  def mark_completed!
    recalculate_stats!
    update!(import_status: 'completed')
  end

  def mark_failed!(message)
    update!(import_status: 'failed', error_message: message)
  end

  # Computes a fingerprint of the raw payload for re-import detection
  def compute_source_hash
    return nil unless raw_payload.present?
    Digest::SHA256.hexdigest(raw_payload.to_json)
  end

  def duplicate_import?
    h = compute_source_hash
    return false if h.blank?
    self.class.
      where(organization_id: organization_id, gstin: gstin, month: month, year: year).
      where(source_hash: h).
      where.not(id: id).
      exists?
  end
end
