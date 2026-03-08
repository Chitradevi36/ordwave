class SalesInvoice < ApplicationRecord
  STATUSES           = %w[draft issued partially_paid void].freeze
  GENERATION_SOURCES = %w[auto_on_delivery manual_from_order manual_direct].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :sales_order, optional: true
  belongs_to :created_by,  class_name: 'User'

  has_many :lines,               class_name: 'SalesInvoiceLine', dependent: :destroy, inverse_of: :sales_invoice
  include Auditable

  has_many :products,            through: :lines
  has_many :payment_allocations, dependent: :destroy
  has_many :payments,            through: :payment_allocations

  accepts_nested_attributes_for :lines, allow_destroy: false

  has_one_attached :pdf_document

  # ── Validations ──────────────────────────────────────────────────────────
  validates :invoice_number, presence: true,
                             uniqueness: { scope: :organization_id,
                                           conditions: -> { where(deleted_at: nil) } }
  validates :invoice_date, presence: true
  validates :status,       inclusion: { in: STATUSES }
  validates :currency,     presence: true
  validates :generation_source, inclusion: { in: GENERATION_SOURCES }, allow_blank: true

  validates :void_reason, presence: true, if: :void?

  validate :due_date_after_invoice_date, if: -> { due_date.present? && invoice_date.present? }
  validate :immutable_when_issued,        on: :update

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :not_deleted,    -> { where(deleted_at: nil) }
  scope :for_org,        ->(org) { where(organization: org) }
  scope :by_status,      ->(s)   { where(status: s) }
  scope :by_customer,    ->(c)   { where(customer: c) }
  scope :by_branch,      ->(b)   { where(branch: b) }
  scope :by_sales_order, ->(o)   { where(sales_order: o) }
  scope :outstanding,    ->      { where(status: %w[issued partially_paid]) }
  scope :recent,         ->      { order(invoice_date: :desc, created_at: :desc) }
  scope :in_date_range,  ->(from_d, to_d) {
    s = all
    s = s.where('invoice_date >= ?', from_d.to_date) if from_d.present?
    s = s.where('invoice_date <= ?', to_d.to_date)   if to_d.present?
    s
  }
  scope :search_query, ->(q) {
    where('invoice_number ILIKE :q', q: "%#{q}%")
  }

  # ── Status helpers ────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def editable?
    draft?
  end

  def voidable?
    issued? || partially_paid?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # ── Totals (recompute from lines and persist) ────────────────────────────
  def recalculate_totals!
    sub   = lines.sum { |l| l.taxable_value.to_d }
    taxes = lines.sum { |l| l.tax_amount.to_d }
    grand = (sub + taxes).round(2)
    update_columns(
      subtotal:    sub.round(2),
      tax_total:   taxes.round(2),
      grand_total: grand
    )
  end

  # ── Tax summary aggregated across lines ──────────────────────────────────
  def tax_breakup
    {
      cgst_total: lines.sum { |l| l.cgst_amount.to_d }.round(2),
      sgst_total: lines.sum { |l| l.sgst_amount.to_d }.round(2),
      igst_total: lines.sum { |l| l.igst_amount.to_d }.round(2),
      hsn_summary: lines.group_by(&:hsn_code).transform_values { |ls|
        {
          taxable_value: ls.sum { |l| l.taxable_value.to_d }.round(2),
          gst_rate:      ls.first.gst_rate,
          tax_amount:    ls.sum { |l| l.tax_amount.to_d }.round(2)
        }
      }
    }
  end

  # gst_summary is an alias used by Gst::EinvoiceService — must appear after tax_breakup is defined
  alias_method :gst_summary, :tax_breakup

  # ── Number generator ─────────────────────────────────────────────────────
  def self.generate_invoice_number(organization:, branch:)
    prefix  = "SI-#{branch.code}-#{Time.current.strftime('%Y%m')}"
    max_seq = where(organization: organization)
              .where("invoice_number LIKE ?", "#{prefix}-%")
              .count
    "#{prefix}-#{(max_seq + 1).to_s.rjust(4, '0')}"
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "invoice_issued",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    issued? || partially_paid?
  end

  private

  def due_date_after_invoice_date
    errors.add(:due_date, 'must be on or after invoice date') if due_date < invoice_date
  end

  def immutable_when_issued
    return if status_changed?  # allow status transitions

    if issued? || void?
      immutable_cols = %w[subtotal tax_total grand_total lines customer_id branch_id
                          sales_order_id invoice_date invoice_number]
      changed_fields = changed.map(&:to_s) & immutable_cols
      if changed_fields.any?
        errors.add(:base, "Issued/voided invoices are immutable (changed: #{changed_fields.join(', ')})")
      end
    end
  end
end
