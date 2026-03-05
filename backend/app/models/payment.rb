class Payment < ApplicationRecord
  PAYMENT_MODES = %w[cash bank_transfer upi cheque neft rtgs adjustment].freeze
  STATUSES      = %w[draft confirmed reversed].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :created_by, class_name: 'User'

  has_many :allocations,      class_name: 'PaymentAllocation', dependent: :destroy
  has_many :sales_invoices,   through: :allocations
  has_many :advance_payments, foreign_key: :source_payment_id, dependent: :destroy
  has_many :audit_logs,       as: :auditable, dependent: :nullify

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :payment_number,  presence: true,
                              uniqueness: { scope: :organization_id }
  validates :amount,          numericality: { greater_than: 0 }
  validates :payment_mode,    inclusion: { in: PAYMENT_MODES }
  validates :status,          inclusion: { in: STATUSES }
  validates :received_date,   presence: true
  validates :reversal_reason, presence: true, if: :reversed?

  # ── Scopes ────────────────────────────────────────────────────────────────────
  scope :for_org,       ->(org)  { where(organization: org) }
  scope :for_branch,    ->(b)    { where(branch: b) }
  scope :for_customer,  ->(c)    { where(customer: c) }
  scope :by_status,     ->(s)    { where(status: s) }
  scope :by_mode,       ->(m)    { where(payment_mode: m) }
  scope :recent,        ->       { order(received_date: :desc, created_at: :desc) }
  scope :confirmed,     ->       { where(status: 'confirmed') }
  scope :in_date_range, ->(from_d, to_d) {
    s = all
    s = s.where('received_date >= ?', from_d.to_date) if from_d.present?
    s = s.where('received_date <= ?', to_d.to_date)   if to_d.present?
    s
  }
  scope :search_query,  ->(q) {
    where('payment_number ILIKE :q OR reference_number ILIKE :q', q: "%#{q}%")
  }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def confirmable? = draft?
  def reversible?  = confirmed?

  # ── Number generation ─────────────────────────────────────────────────────────
  # Format: PAY-{BRANCH_CODE}-{YYYYMM}-{0001}
  def self.generate_payment_number(organization:, branch:)
    prefix  = "PAY-#{branch.code.upcase}-#{Time.current.strftime('%Y%m')}"
    max_seq = where(organization: organization)
                .where("payment_number LIKE ?", "#{prefix}-%")
                .count
    "#{prefix}-#{(max_seq + 1).to_s.rjust(4, '0')}"
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────
  def overallocated?
    allocated_amount > amount
  end
end
