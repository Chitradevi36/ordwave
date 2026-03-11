# frozen_string_literal: true

class BankAccount < ApplicationRecord
  STATUSES = %w[active inactive].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch, optional: true

  has_many :bank_statement_imports, dependent: :destroy
  has_many :bank_transactions,      dependent: :destroy

  # ── Validations ──────────────────────────────────────────────────────────
  validates :bank_name,             presence: true
  validates :account_name,          presence: true
  validates :account_number_masked, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :ifsc,   format: { with: /\A[A-Z]{4}0[A-Z0-9]{6}\z/ }, allow_blank: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :active,   -> { where(status: "active") }
  scope :for_org,  ->(org) { where(organization: org) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  # ── Helpers ───────────────────────────────────────────────────────────────
  # Returns a masked display string like "HDFC Bank ••••4321"
  def display_name
    "#{bank_name} #{account_number_masked}"
  end
end
