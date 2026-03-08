class PurchaseInvoice < ApplicationRecord
  STATUSES = %w[draft posted cancelled].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :supplier
  belongs_to :created_by, class_name: 'User'

  has_many :lines,           class_name: 'PurchaseInvoiceLine',
                             foreign_key: :purchase_invoice_id,
                             dependent: :destroy,
                             inverse_of: :purchase_invoice
  has_many :stock_movements, as: :reference, dependent: :nullify
  has_many :products, through: :lines

  accepts_nested_attributes_for :lines,
                                allow_destroy: true,
                                reject_if: :all_blank

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :invoice_number, presence: true, length: { maximum: 100 }
  validates :invoice_number, uniqueness: {
    scope:      :supplier_id,
    conditions: -> { where(deleted_at: nil) },
    message:    'has already been used for this supplier'
  }
  validates :invoice_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, presence: true

  validate :due_date_after_invoice_date, if: -> { due_date.present? && invoice_date.present? }
  validate :immutable_when_posted_or_cancelled, on: :update

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :not_deleted,  ->        { where(deleted_at: nil) }
  scope :by_status,    ->(s)     { where(status: s) }
  scope :for_org,      ->(org)   { where(organization: org) }
  scope :for_supplier, ->(s)     { where(supplier: s) }
  scope :for_branch,   ->(b)     { where(branch: b) }
  scope :in_date_range, ->(from, to) {
    scope = all
    scope = scope.where('invoice_date >= ?', from) if from.present?
    scope = scope.where('invoice_date <= ?', to)   if to.present?
    scope
  }
  scope :search_query, ->(q) {
    where('invoice_number ILIKE :q', q: "%#{q}%")
  }

  # ── State helpers ─────────────────────────────────────────────────────────────
  def draft?;     status == 'draft'; end
  def posted?;    status == 'posted'; end
  def cancelled?; status == 'cancelled'; end
  def editable?;  draft?; end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # ── Computed totals (recalculated from lines) ─────────────────────────────────
  def recalculate_totals!
    base  = lines.sum(&:subtotal)        # qty * unit_price after discount
    taxes = lines.sum(&:tax_amount)
    update_columns(
      total_amount: base.round(2),
      tax_amount:   taxes.round(2),
      grand_total:  (base + taxes).round(2)
    )
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "purchase_invoice_posted",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    posted?
  end

  private

  def due_date_after_invoice_date
    errors.add(:due_date, 'must be on or after invoice date') if due_date < invoice_date
  end

  def immutable_when_posted_or_cancelled
    return if status_changed?  # allow status transition itself
    if posted? || cancelled?
      changed_fields = changed - ['status', 'updated_at']
      errors.add(:base, "Posted or cancelled invoices cannot be edited") if changed_fields.any?
    end
  end
end
