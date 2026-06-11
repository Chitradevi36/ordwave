class Customer < ApplicationRecord
  CHANNELS       = %w[general_trade modern_trade horeca pharmacy electronics wholesale distributor].freeze
  TIERS          = %w[platinum gold silver bronze].freeze
  STATUSES       = %w[active inactive blocked].freeze
  CUSTOMER_TYPES = %w[retailer wholesaler distributor institution horeca online other].freeze
  VISIT_FREQS    = %w[daily weekly biweekly monthly quarterly].freeze
  BLOCK_RULES    = %w[none soft_block hard_block].freeze

  # Associations
  belongs_to :organization
  belongs_to :branch
  belongs_to :route,     optional: true
  belongs_to :sales_rep, class_name: 'User', optional: true

  has_many :addresses,
           class_name: 'CustomerAddress',
           dependent:  :destroy

  has_many :contacts,
           class_name: 'CustomerContact',
           dependent:  :destroy

  has_one :credit_account, dependent: :destroy
  has_many :sales_orders, dependent: :restrict_with_error
  has_many :return_requests, dependent: :destroy
  has_many :credit_notes,   dependent: :nullify
  has_many :sales_invoices, dependent: :restrict_with_error
  has_many :payments,        dependent: :restrict_with_error
  has_many :advance_payments,          dependent: :destroy
  has_many :customer_aliases,           dependent: :destroy
  has_many :expected_payment_references, dependent: :destroy
  has_many :bank_transaction_matches,   dependent: :nullify
  has_many :beat_retailers,  dependent: :destroy
  has_many :visit_logs,      dependent: :destroy

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :contacts,  allow_destroy: true

  # ── Credit limit (denormalized) ──────────────────────────────────────────
  # DEPRECATED: This column duplicates CreditAccount#credit_limit and can drift.
  # Authoritative credit data lives in the associated CreditAccount record.
  # Use customer.credit_account.credit_limit for all credit enforcement logic.
  # This field is kept for historical API compatibility only.
  #
  # Validations
  validates :name,   presence: true, length: { maximum: 150 }
  validates :code,   presence: true,
                     uniqueness: { scope: :organization_id, message: 'has already been taken for this organization' }
  # Phone must be provided when creating a new retailer and follow the 10-digit format
  validates :phone, presence: true, on: :create
  validates :phone, format: { with: /\A[0-9]{10}\z/, message: 'must be a 10-digit number' }, allow_blank: true
  validates :phone, uniqueness: { scope: :organization_id, message: 'has already been taken for this organization' }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }, allow_blank: true
  validates :tier,    inclusion: { in: TIERS },    allow_blank: true
  validates :gstin, format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/,
                             message: 'is not a valid GSTIN' }, allow_blank: true
  validates :customer_type,     inclusion: { in: CUSTOMER_TYPES }, allow_blank: true
  validates :visit_frequency,   inclusion: { in: VISIT_FREQS },    allow_blank: true
  validates :credit_block_rule, inclusion: { in: BLOCK_RULES },    allow_blank: true
  validates :credit_days,       numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active,           -> { where(status: 'active', deleted_at: nil) }
  scope :not_deleted,      -> { where(deleted_at: nil) }
  scope :by_channel,       ->(ch)  { where(channel: ch) }
  scope :by_route,         ->(rid) { where(route_id: rid) }
  scope :by_tier,          ->(t)   { where(tier: t) }
  scope :by_customer_type, ->(ct)  { where(customer_type: ct) }
  scope :by_sales_rep,     ->(uid) { where(sales_rep_id: uid) }
  scope :by_status,        ->(s)   { where(status: s) }
  scope :tagged_with,      ->(tag) { where('? = ANY(tag_list)', tag) }

  # Credit-intelligence scopes
  scope :overdue_customers, lambda {
    joins(:credit_account).where('credit_accounts.overdue_amount > 0')
  }
  scope :near_credit_limit, lambda {
    joins(:credit_account)
      .where('credit_accounts.credit_limit > 0')
      .where(
        '(credit_accounts.current_balance::numeric / NULLIF(credit_accounts.credit_limit, 0)) >= 0.8'
      )
  }
  scope :no_route,   -> { where(route_id: nil) }

  # Visit tracking scopes
  scope :due_for_visit, ->(as_of = Date.current) {
    where("next_due_on IS NULL OR next_due_on <= ?", as_of)
      .where.not(visit_frequency: nil)
  }
  scope :never_visited, -> { where(last_visited_at: nil).where.not(visit_frequency: nil) }
  scope :visit_overdue, ->(as_of = Date.current) {
    where("next_due_on < ?", as_of).where.not(visit_frequency: nil)
  }

  # Duplicate detection
  scope :dup_by_name,  ->(val, org_id) { not_deleted.where(organization_id: org_id).where('LOWER(name) = LOWER(?)', val) }
  scope :dup_by_phone, ->(val, org_id) { not_deleted.where(organization_id: org_id).where(phone: val) }
  scope :dup_by_gstin, ->(val, org_id) { not_deleted.where(organization_id: org_id).where(gstin: val) }

  # Normalize optional fields: store empty GSTIN/PAN as NULL so unique partial indexes behave correctly
  before_validation :normalize_optional_identifiers

  private

  def normalize_optional_identifiers
    self.gstin = nil if gstin.present? && gstin.strip == ""
    self.pan   = nil if pan.present? && pan.strip == ""
  end

  def soft_delete!
    update!(deleted_at: Time.current, status: 'inactive')
  end

  def deleted?
    deleted_at.present?
  end

  def block!
    update!(status: 'blocked')
    WebhookEvents.fire(
      organization: organization,
      event:        'customer.credit_blocked',
      payload:      WebhookEvents.customer_payload(self)
    )
  end

  def unblock!
    update!(status: 'active')
  end

  def deactivate!
    update!(status: 'inactive')
  end

  def active?   = status == 'active'
  def blocked?  = status == 'blocked'

  # ── Visit frequency helpers ───────────────────────────────────────────────
  VISIT_FREQ_DAYS = {
    'daily'     => 1,
    'weekly'    => 7,
    'biweekly'  => 14,
    'monthly'   => 30,
    'quarterly' => 90
  }.freeze

  def due_for_visit?(as_of = Date.current)
    return false if visit_frequency.blank?
    return true  if last_visited_at.nil?
    return true  if next_due_on.present? && next_due_on <= as_of

    days = VISIT_FREQ_DAYS[visit_frequency]
    days ? last_visited_at.to_date + days <= as_of : false
  end

  def compute_next_due_on(from_date = Date.current)
    days = VISIT_FREQ_DAYS[visit_frequency]
    return nil unless days

    from_date + days
  end

  def record_visit!(visited_at = Time.current)
    update!(
      last_visited_at: visited_at,
      next_due_on:     compute_next_due_on(visited_at.to_date)
    )
  end

  # ── Accounting Sync Triggers ────────────────────────────────────────────────
  include AccountingSyncTriggers

  accounting_sync_trigger(
    event_type: "retailer_synced",
    on:         %i[create update],
    if:         :sync_to_accounting?
  )

  def sync_to_accounting?
    active?
  end
end
