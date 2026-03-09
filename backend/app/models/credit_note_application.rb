# frozen_string_literal: true

class CreditNoteApplication < ApplicationRecord
  STATUSES = %w[active reversed].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :credit_note
  belongs_to :sales_invoice
  belongs_to :applied_by, class_name: 'User'

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validate  :credit_note_must_be_issued
  validate  :amount_within_limits

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :active, -> { where(status: 'active') }
  scope :reversed, -> { where(status: 'reversed') }
  scope :for_credit_note, ->(cn_id) { where(credit_note_id: cn_id) }
  scope :for_invoice, ->(inv_id) { where(sales_invoice_id: inv_id) }

  # ── State helpers ────────────────────────────────────────────────────────────
  def active?;   status == 'active'; end
  def reversed?; status == 'reversed'; end

  def reverse!(reason:, actor: nil)
    update!(
      status:           'reversed',
      reversed_at:      Time.current,
      reversal_reason:  reason
    )
  end

  private

  def credit_note_must_be_issued
    return unless credit_note
    errors.add(:credit_note, 'must be in issued status') unless credit_note.status == 'issued'
  end

  def amount_within_limits
    return unless credit_note && sales_invoice && amount.present?

    # Cannot exceed unapplied amount on credit note
    unapplied = credit_note.unapplied_amount.to_d
    if active? && amount > unapplied + (amount_was || 0).to_d
      errors.add(:amount, "exceeds available credit note balance (#{unapplied})")
    end

    # Cannot exceed outstanding amount on invoice
    outstanding = sales_invoice.outstanding_amount.to_d
    if active? && amount > outstanding
      errors.add(:amount, "exceeds invoice outstanding amount (#{outstanding})")
    end
  end
end
