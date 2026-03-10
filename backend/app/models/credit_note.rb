class CreditNote < ApplicationRecord
  STATUSES = %w[draft issued void].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :return_request, optional: true
  belongs_to :sales_order, optional: true
  belongs_to :created_by, class_name: 'User'

  has_many :lines,        class_name: 'CreditNoteLine', dependent: :destroy, inverse_of: :credit_note
  has_many :applications, class_name: 'CreditNoteApplication', dependent: :restrict_with_error
  has_many :audit_logs,   as: :auditable,               dependent: :nullify

  belongs_to :applied_to_invoice, class_name: 'SalesInvoice', optional: true

  accepts_nested_attributes_for :lines, allow_destroy: false

  # ── Validations ────────────────────────────────────────────────────────────
  validates :credit_note_number, presence: true,
                                 uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }

  # ── Callbacks ──────────────────────────────────────────────────────────────
  before_validation :assign_credit_note_number, on: :create

  # ── Scopes ─────────────────────────────────────────────────────────────────
  scope :not_deleted,   -> { where(deleted_at: nil) }
  scope :for_org,       ->(org) { where(organization: org) }
  scope :by_status,     ->(s)   { where(status: s) }
  scope :by_customer,   ->(cid) { where(customer_id: cid) }
  scope :recent,        -> { order(created_at: :desc) }
  scope :with_unapplied_balance, -> { where('unapplied_amount > 0') }

  # ── Status helpers ─────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def fully_applied?
    unapplied_amount.to_d.zero? && applied_amount.to_d.positive?
  end

  def partially_applied?
    applied_amount.to_d.positive? && unapplied_amount.to_d.positive?
  end

  def recalculate_totals!
    sub     = lines.sum(:line_total)
    tax     = lines.sum(:tax_amount)
    new_total = sub + tax
    update!(
      subtotal: sub, tax_total: tax, total: new_total,
      unapplied_amount: new_total - applied_amount.to_d
    )
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "credit_note_issued",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    issued?
  end

  private

  def assign_credit_note_number
    return if credit_note_number.present?

    max = CreditNote.where(organization_id: organization_id).maximum(:id).to_i
    self.credit_note_number = "CN-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end
end
