# frozen_string_literal: true

# GstReturnSnapshot stores an immutable computed snapshot for a GST return period.
#
# Snapshots are never mutated after creation. Multiple draft versions can exist
# before filing. Once filed?, the snapshot records compliance-grade immutable data.
#
# section_key identifies the return section:
#   GSTR-1: 'b2b', 'b2cl', 'b2cs', 'cdnr', 'cdnur', 'hsn', 'nil_exempt', 'doc_issue', 'full'
#   GSTR-3B: 'gstr3b_table3_1', 'gstr3b_table4', 'gstr3b_table6', 'gstr3b_full'
#
class GstReturnSnapshot < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :gst_return_period
  belongs_to :organization

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :section_key,     presence: true
  validates :version_number,  presence: true, numericality: { greater_than: 0 }
  validates :generated_at,    presence: true

  # Prevent mutation after creation (immutability contract)
  validate :not_mutated_after_filed, on: :update

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_period,   ->(p)     { where(gst_return_period: p) }
  scope :for_section,  ->(key)   { where(section_key: key) }
  scope :filed,        ->        { where(is_filed: true) }
  scope :latest_first, ->        { order(version_number: :desc) }
  scope :for_org,      ->(org)   { where(organization: org) }

  # ── Convenience helpers ──────────────────────────────────────────────────────

  def filed?
    is_filed == true
  end

  # Returns stringified total for display
  def total_taxable_value
    totals['taxable_value']&.to_d || 0
  end

  def total_tax_value
    totals['tax_value']&.to_d || 0
  end

  def total_invoice_count
    source_counts['invoices']&.to_i || 0
  end

  # Verify payload integrity using stored snapshot_hash
  def integrity_valid?
    return true if snapshot_hash.blank?
    Digest::SHA256.hexdigest(payload.to_json) == snapshot_hash
  end

  private

  def not_mutated_after_filed
    return unless is_filed_was == true && is_filed == true
    errors.add(:base, "Filed snapshots are immutable and cannot be changed")
  end
end
