# frozen_string_literal: true

# Gst2bImportLine represents one invoice row from a GSTR-2B import.
#
# After parsing, each line is matched against PurchaseInvoices in books.
# The match_status captures the reconciliation result.
#
# Document types (from portal): invoice / credit_note / debit_note / advance / isd
# Section types (from portal):  b2b / b2ba / cdn / cdna / isd / impg / impgsez
#
# Match statuses (reconciliation outcomes):
#   pending             — not yet run through matching engine
#   matched             — exact or high-confidence match found
#   partial_match       — some fields match (e.g. GSTIN + amount but different inv number)
#   multiple_candidates — 2+ possible matches in books; manual resolution needed
#   missing_in_books    — line is in 2B but no purchase invoice found in books
#   missing_in_2b       — purchase invoice in books but not appearing in 2B (set aside for companion)
#   tax_mismatch        — invoice matched by number but tax amounts differ
#   gstin_mismatch      — invoice found but supplier GSTIN doesn't match
#   date_mismatch       — invoice found but dates differ by more than tolerance
#   ignored             — manually marked as "do not reconcile"
#
class Gst2bImportLine < ApplicationRecord
  DOCUMENT_TYPES = %w[invoice credit_note debit_note advance isd].freeze
  SECTION_TYPES  = %w[b2b b2ba cdn cdna isd impg impgsez].freeze
  MATCH_STATUSES = %w[
    pending matched partial_match multiple_candidates
    missing_in_books missing_in_2b
    tax_mismatch gstin_mismatch date_mismatch ignored
  ].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :gst2b_import
  belongs_to :organization
  belongs_to :matched_purchase_invoice, class_name: 'PurchaseInvoice', optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :supplier_gstin,  presence: true,
                              format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/,
                                        message: 'must be a valid GSTIN' }
  validates :invoice_number,  presence: true
  validates :document_type,   inclusion: { in: DOCUMENT_TYPES }, allow_nil: true
  validates :section_type,    inclusion: { in: SECTION_TYPES },  allow_nil: true
  validates :match_status,    inclusion: { in: MATCH_STATUSES }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_import,             ->(imp) { where(gst2b_import: imp) }
  scope :pending,                ->      { where(match_status: 'pending') }
  scope :matched,                ->      { where(match_status: 'matched') }
  scope :unresolved,             ->      { where(match_status: %w[pending partial_match multiple_candidates]) }
  scope :problematic,            ->      { where(match_status: %w[tax_mismatch gstin_mismatch date_mismatch]) }
  scope :missing_in_books,       ->      { where(match_status: 'missing_in_books') }
  scope :itc_eligible,           ->      { where(itc_available: true) }
  scope :reverse_charge,         ->      { where(reverse_charge: true) }
  scope :for_supplier,           ->(g)   { where(supplier_gstin: g) }

  # ── Helpers ───────────────────────────────────────────────────────────────────

  def matched?
    match_status == 'matched'
  end

  def ignored?
    match_status == 'ignored'
  end

  def total_tax
    (igst || 0) + (cgst || 0) + (sgst || 0) + (cess || 0)
  end

  def books_match_label
    return 'Exact match' if match_status == 'matched' && match_confidence.to_f >= 0.95
    return 'Likely match' if match_status == 'matched'
    return 'Multiple candidates' if match_status == 'multiple_candidates'
    match_status.humanize
  end

  def invoice_value_bd
    invoice_value&.to_d || 0
  end

  def taxable_value_bd
    taxable_value&.to_d || 0
  end

  # ── Matching helpers ──────────────────────────────────────────────────────────

  def apply_match!(purchase_invoice:, confidence:, explanation: nil)
    update!(
      matched_purchase_invoice: purchase_invoice,
      match_status:        'matched',
      match_confidence:    confidence,
      match_explanation:   explanation
    )
  end

  def mark_missing_in_books!
    update!(match_status: 'missing_in_books', match_confidence: 1.0)
  end

  def mark_ignored!(reason: nil)
    update!(match_status: 'ignored', match_explanation: reason)
  end
end
