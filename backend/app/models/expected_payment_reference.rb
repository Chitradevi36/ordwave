# frozen_string_literal: true

# Stores expected inbound reference values so the matching engine can do an
# exact lookup (e.g. a UTR told to the retailer when asking them to pay).
class ExpectedPaymentReference < ApplicationRecord
  REFERENCE_TYPES = %w[utr invoice_number customer_code custom].freeze
  STATUSES        = %w[pending matched expired].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :customer,      optional: true
  belongs_to :sales_invoice, optional: true

  # ── Validations ──────────────────────────────────────────────────────────
  validates :reference_type,  inclusion: { in: REFERENCE_TYPES }
  validates :reference_value, presence: true
  validates :status,          inclusion: { in: STATUSES }
  validates :reference_value, uniqueness: {
    scope: %i[organization_id reference_type],
    message: "already registered"
  }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :pending,  -> { where(status: "pending") }
  scope :for_org,  ->(org) { where(organization: org) }
  scope :by_value, ->(v)   { where(reference_value: v.to_s.strip.upcase) }

  # ── Normalise before save ─────────────────────────────────────────────────
  before_save { self.reference_value = reference_value.to_s.strip.upcase }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }
end
