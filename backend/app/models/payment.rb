class Payment < ApplicationRecord
  PAYMENT_MODES = %w[cash bank_transfer upi cheque neft rtgs adjustment tally_sync razorpay].freeze
  STATUSES      = %w[draft confirmed reversed].freeze
  EXTERNAL_STATUSES = %w[authorized captured failed declined].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :created_by, class_name: 'User'
  belongs_to :reversed_by, class_name: 'User', optional: true

  has_many :allocations,      class_name: 'PaymentAllocation', dependent: :destroy
  has_many :sales_invoices,   through: :allocations
  has_many :advance_payments, foreign_key: :source_payment_id, dependent: :destroy
  has_many :auto_post_audits, dependent: :destroy
  has_many :rejection_feedbacks, dependent: :destroy
  include Auditable


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
  scope :external_payments, -> { where(payment_mode: 'razorpay') }
  scope :successful_external, -> { where(external_payment_status: %w[captured authorized]) }
  scope :auto_posted, -> { where(auto_posted: true) }
  scope :manual_posted, -> { where(auto_posted: false) }
  scope :pending_rejection, -> { where('rejection_window_expires_at > ?', Time.current) }
  scope :auto_posting_expired, -> { where('rejection_window_expires_at <= ?', Time.current) }

  # ── Status helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def confirmable? = draft?
  def reversible?  = confirmed?
  def external_payment? = payment_mode == 'razorpay'
  def external_successful? = external_payment_status.in?(%w[captured authorized])

  # ── Callbacks ────────────────────────────────────────────────────────────────
  after_save :sync_to_invoices!, if: :saved_change_to_status?

  # ── Number generation ─────────────────────────────────────────────────────────
  # Format: PAY-{BRANCH_CODE}-{YYYYMM}-{0001}
  def self.generate_payment_number(organization:, branch:)
    prefix  = "PAY-#{branch.code.upcase}-#{Time.current.strftime('%Y%m')}"
    max_seq = where(organization: organization)
                .where("payment_number LIKE ?", "#{prefix}-%")
                .count
    "#{prefix}-#{(max_seq + 1).to_s.rjust(4, '0')}"
  end

  # ── Razorpay Payment Processing ──────────────────────────────────────────────
  def self.from_razorpay_webhook(payload, organization, invoice: nil)
    # payload = Razorpay payment object from webhook
    # { id, amount, status, method, customer, ... }
    
    external_id = payload['id']
    amount_paise = payload['amount'].to_i
    amount_rupees = amount_paise.to_f / 100

    payment = find_or_initialize_by(
      organization: organization,
      external_payment_id: external_id
    )

    payment.assign_attributes(
      amount:                  amount_rupees,
      payment_mode:            'razorpay',
      status:                  'draft',  # Will confirm after we link to invoice
      received_date:           Date.current,
      external_payload_data:   payload,
      external_payment_status: parse_razorpay_status(payload['status']),
      external_confirmed_at:   payload['captured_at'] ? Time.at(payload['captured_at']) : nil
    )

    # If invoice provided, auto-allocate payment to invoice
    if payment.save! && invoice.present?
      PaymentAllocation.create!(
        payment:        payment,
        sales_invoice:  invoice,
        allocated_amount: amount_rupees
      )
    end

    payment
  end

  def self.parse_razorpay_status(razorpay_status)
    case razorpay_status
    when 'authorized' then 'authorized'
    when 'captured' then 'captured'
    when 'failed', 'refunded' then 'failed'
    when 'declined' then 'declined'
    else 'unknown'
    end
  end

  # Mark payment as manually confirmed (e.g., admin approval of external payment)
  def confirm_external_payment!
    return false unless external_payment? && external_successful?
    
    update!(
      status: 'confirmed',
      external_confirmed_at: Time.current
    )
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────
  def overallocated?
    allocated_amount > amount
  end

  # ── Payment → Invoice Sync ───────────────────────────────────────────────────
  # When payment is confirmed, update linked invoice paid_at status
  def sync_to_invoices!
    return unless confirmed? && external_successful?

    sales_invoices.each do |invoice|
      next if invoice.paid_at.present?  # Already marked paid

      invoice.update!(
        paid_at: external_confirmed_at || Time.current,
        status:  'paid'
      )

      # Cascade: if all invoices paid, mark order as paid
      if invoice.sales_order.present?
        if invoice.sales_order.sales_invoices.all? { |inv| inv.paid_at.present? }
          invoice.sales_order.update!(status: 'paid')
        end
      end
    end
  end

  # ── Auto-Posting Helpers ────────────────────────────────────────────────────
  def auto_posted?
    auto_posted.present? && auto_posted == true
  end

  def manual_posted?
    !auto_posted?
  end

  def can_reject?
    auto_posted? && rejection_window_expires_at.present? && Time.current < rejection_window_expires_at
  end

  def rejection_window_expired?
    !can_reject?
  end

  def time_until_rejection_expires
    return nil unless rejection_window_expires_at.present?
    (rejection_window_expires_at - Time.current).round
  end

  def reversed?
    status == 'reversed'
  end

  def confidence_grade
    return 'manual' if !auto_posted?
    return nil if confidence_score.blank?

    case confidence_score
    when 95..100
      'high'
    when 85..94
      'medium'
    else
      'low'
    end
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "payment_recorded",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    confirmed?
  end
end
