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

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :contacts,  allow_destroy: true

  # Validations
  validates :name,   presence: true, length: { maximum: 150 }
  validates :code,   presence: true,
                     uniqueness: { scope: :organization_id, message: 'has already been taken for this organization' }
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
  scope :no_route, -> { where(route_id: nil) }

  # Duplicate detection
  scope :dup_by_name,  ->(val, org_id) { not_deleted.where(organization_id: org_id).where('LOWER(name) = LOWER(?)', val) }
  scope :dup_by_phone, ->(val, org_id) { not_deleted.where(organization_id: org_id).where(phone: val) }
  scope :dup_by_gstin, ->(val, org_id) { not_deleted.where(organization_id: org_id).where(gstin: val) }

  def soft_delete!
    update!(deleted_at: Time.current, status: 'inactive')
  end

  def deleted?
    deleted_at.present?
  end

  def block!
    update!(status: 'blocked')
  end

  def unblock!
    update!(status: 'active')
  end

  def deactivate!
    update!(status: 'inactive')
  end

  def active?   = status == 'active'
  def blocked?  = status == 'blocked'
end
