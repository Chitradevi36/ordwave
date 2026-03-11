# frozen_string_literal: true

# Represents a detected GST amendment candidate — a document that was
# created or modified _after_ a GSTR-1 was filed for its period.
#
# Lifecycle:
#   detected → acknowledged → included_in_amendment
#                           → dismissed
#
# Amendment types:
#   new_invoice       — invoice created after filing (goes to GSTR-1A as new)
#   modified_invoice  — invoice updated after filing (goes to GSTR-1A as amendment)
#   new_cn            — credit note issued after filing
#   modified_cn       — credit note updated after filing
#   cancelled_invoice — invoice voided after filing
#
class GstAmendmentCandidate < ApplicationRecord
  AMENDMENT_TYPES = %w[
    new_invoice
    modified_invoice
    new_cn
    modified_cn
    cancelled_invoice
  ].freeze

  STATUSES = %w[
    detected
    acknowledged
    included_in_amendment
    dismissed
  ].freeze

  # ── Associations ─────────────────────────────────────────────────────────────

  belongs_to :organization
  belongs_to :gst_return_period
  belongs_to :source,          polymorphic: true, optional: true
  belongs_to :acknowledged_by, class_name: 'User', optional: true

  # ── Validations ──────────────────────────────────────────────────────────────

  validates :source_type,    inclusion: { in: %w[SalesInvoice CreditNote] }
  validates :amendment_type, inclusion: { in: AMENDMENT_TYPES }
  validates :status,         inclusion: { in: STATUSES }
  validates :detected_at,    presence: true

  validate :acknowledged_fields_present_when_acknowledged

  # ── Scopes ───────────────────────────────────────────────────────────────────

  scope :for_org,    ->(org)    { where(organization: org) }
  scope :for_period, ->(period) { where(gst_return_period: period) }
  scope :open,       ->         { where(status: %w[detected acknowledged]) }
  scope :closed,     ->         { where(status: %w[included_in_amendment dismissed]) }
  scope :by_type,    ->(type)   { where(amendment_type: type) }

  # ── Status helpers ────────────────────────────────────────────────────────────

  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  def open?
    %w[detected acknowledged].include?(status)
  end

  # ── Mutations ────────────────────────────────────────────────────────────────

  # Mark as acknowledged by a user (CA review step).
  def acknowledge!(by_user:)
    raise ArgumentError, 'User is required' unless by_user

    update!(
      status:              'acknowledged',
      acknowledged_by:     by_user,
      acknowledged_at:     Time.current
    )
  end

  # Mark as included after generating the amendment return.
  def mark_included!
    update!(status: 'included_in_amendment')
  end

  def dismiss!
    update!(status: 'dismissed')
  end

  # ── Serialisation helpers ─────────────────────────────────────────────────────

  def document_number
    source&.try(:invoice_number) ||
      source&.try(:credit_note_number) ||
      "#{source_type}##{source_id}"
  end

  private

  def acknowledged_fields_present_when_acknowledged
    return unless status == 'acknowledged'

    errors.add(:acknowledged_by, 'must be present when status is acknowledged') if acknowledged_by.nil?
    errors.add(:acknowledged_at, 'must be present when status is acknowledged') if acknowledged_at.nil?
  end
end
