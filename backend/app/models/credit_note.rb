class CreditNote < ApplicationRecord
  STATUSES = %w[draft issued void].freeze

  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :return_request
  belongs_to :sales_order, optional: true
  belongs_to :created_by, class_name: 'User'

  has_many :lines,      class_name: 'CreditNoteLine', dependent: :destroy, inverse_of: :credit_note
  has_many :audit_logs, as: :auditable,               dependent: :nullify

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

  # ── Status helpers ─────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def recalculate_totals!
    sub     = lines.sum(:line_total)
    tax     = lines.sum(:tax_amount)
    update!(subtotal: sub, tax_total: tax, total: sub + tax)
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
