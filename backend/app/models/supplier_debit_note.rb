# frozen_string_literal: true

class SupplierDebitNote < ApplicationRecord
  STATUSES = %w[draft issued void].freeze
  REASONS  = %w[quality_issue expired short_supply damaged wrong_item other].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :supplier
  belongs_to :return_request, optional: true
  belongs_to :created_by, class_name: 'User'

  has_many :lines, class_name: 'SupplierDebitNoteLine',
                   foreign_key: :supplier_debit_note_id,
                   dependent: :destroy,
                   inverse_of: :supplier_debit_note

  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: :all_blank

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :debit_note_number, presence: true, uniqueness: { scope: :organization_id }
  validates :debit_note_date,   presence: true
  validates :status,            inclusion: { in: STATUSES }
  validates :reason,            inclusion: { in: REASONS }

  # ── Callbacks ────────────────────────────────────────────────────────────────
  before_validation :assign_debit_note_number, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :not_deleted,   -> { where(deleted_at: nil) }
  scope :for_org,       ->(org) { where(organization: org) }
  scope :by_status,     ->(s)   { where(status: s) }
  scope :for_supplier,  ->(sid) { where(supplier_id: sid) }
  scope :recent,        -> { order(created_at: :desc) }

  # ── Status helpers ─────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def issue!
    update!(status: 'issued', issued_at: Time.current)
  end

  def void!(reason)
    update!(status: 'void', voided_at: Time.current, void_reason: reason)
  end

  def recalculate_totals!
    sub = lines.sum { |l| l.qty * l.unit_price }
    tax = lines.sum(&:tax_amount)
    update_columns(subtotal: sub.round(2), tax_total: tax.round(2), total: (sub + tax).round(2))
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "supplier_debit_note_issued",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    issued?
  end

  private

  def assign_debit_note_number
    return if debit_note_number.present?

    max = SupplierDebitNote.where(organization_id: organization_id).maximum(:id).to_i
    self.debit_note_number = "SDN-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end
end
