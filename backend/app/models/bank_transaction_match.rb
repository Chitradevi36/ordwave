# frozen_string_literal: true

# Stores every candidate match the engine considered for a given bank transaction.
# The highest-scoring one is flagged `selected: true` and its data is denormalized
# onto BankTransaction for fast querying.
class BankTransactionMatch < ApplicationRecord
  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :bank_transaction
  belongs_to :customer,      optional: true
  belongs_to :sales_invoice, optional: true

  # ── Validations ──────────────────────────────────────────────────────────
  validates :score,     numericality: { in: 0..100 }
  validates :rule_code, presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :selected,   -> { where(selected: true) }
  scope :by_score,   -> { order(score: :desc) }
