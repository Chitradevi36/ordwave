# frozen_string_literal: true

# Alternative names / abbreviated names a customer is known by in bank narrations.
# e.g. "Raju Gen Stores", "RGS", "RAJU STORES" → maps to Customer "Raju General Stores Pvt Ltd"
class CustomerAlias < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :customer

  # ── Validations ──────────────────────────────────────────────────────────
  validates :alias_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :alias_name, uniqueness: {
    scope: :customer_id,
    message: "already exists for this customer"
  }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :for_org, ->(org) { joins(:customer).where(customers: { organization: org }) }
  scope :matching, ->(term) {
    where("UPPER(alias_name) LIKE ?", "%#{term.to_s.upcase.strip}%")
  }

  # ── Normalised alias for matching ─────────────────────────────────────────
  before_save { self.alias_name = alias_name.strip.upcase }
end
