# frozen_string_literal: true

class BankTransaction < ApplicationRecord
  DIRECTIONS = %w[credit debit].freeze

  # Status lifecycle:
  #   unmatched   → no match found yet
  #   suggested   → matcher found a candidate (score 80–94), wait for human review
  #   auto_matched → matcher is ≥95 confident; will be posted automatically
  #   matched     → human confirmed OR auto-match posted; Payment created
  #   ignored     → deliberately skipped (bank fee, internal transfer, etc.)
  #   reversed    → previously matched; Payment reversed, revert to unmatched-like state
  STATUSES = %w[unmatched suggested auto_matched matched ignored reversed].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :bank_account
  belongs_to :bank_statement_import, optional: true

  belongs_to :matched_customer, class_name: "Customer",     optional: true, foreign_key: :matched_customer_id
  belongs_to :matched_invoice,  class_name: "SalesInvoice", optional: true, foreign_key: :matched_invoice_id
  belongs_to :matched_payment,  class_name: "Payment",      optional: true, foreign_key: :matched_payment_id
  belongs_to :reviewed_by,      class_name: "User",         optional: true, foreign_key: :reviewed_by_id

  has_many :candidates, class_name: "BankTransactionMatch", dependent: :destroy

  include Auditable

  # ── Validations ──────────────────────────────────────────────────────────
  validates :txn_date,         presence: true
  validates :amount,           numericality: { greater_than: 0 }
  validates :direction,        inclusion: { in: DIRECTIONS }
  validates :status,           inclusion: { in: STATUSES }
  validates :idempotency_key,  presence: true, uniqueness: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :for_org,       ->(org) { where(organization: org) }
  scope :credits,       ->      { where(direction: "credit") }
  scope :debits,        ->      { where(direction: "debit") }
  scope :by_status,     ->(s)   { where(status: s) }
  scope :unmatched,     ->      { where(status: "unmatched") }
  scope :needs_review,  ->      { where(status: %w[unmatched suggested]) }
  scope :auto_matched,  ->      { where(status: "auto_matched") }
  scope :matched,       ->      { where(status: "matched") }
  scope :ignored,       ->      { where(status: "ignored") }
  scope :in_date_range, ->(from_d, to_d) {
    s = all
    s = s.where("txn_date >= ?", from_d.to_date) if from_d.present?
    s = s.where("txn_date <= ?", to_d.to_date)   if to_d.present?
    s
  }
  scope :recent, -> { order(txn_date: :desc, created_at: :desc) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }
  DIRECTIONS.each { |d| define_method(:"#{d}?") { direction == d } }

  # ── Helpers ───────────────────────────────────────────────────────────────
  def postable?
    credit? && %w[suggested auto_matched].include?(status)
  end

  def ignorable?
    !matched?
  end

  def best_candidate
    candidates.where(selected: true).first || candidates.order(score: :desc).first
  end

  # Generates a deterministic idempotency key from the raw fields
  # so re-importing the same CSV row is a safe no-op.
  def self.build_idempotency_key(bank_account_id:, txn_date:, amount:, reference:, narration:)
    raw = "#{bank_account_id}|#{txn_date}|#{amount}|#{reference.to_s.strip.upcase}|#{narration.to_s.strip[0, 100].upcase}"
    Digest::SHA256.hexdigest(raw)
  end
end
