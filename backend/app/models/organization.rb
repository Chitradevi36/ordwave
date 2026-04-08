class Organization < ApplicationRecord
  # Note: plan is a denormalized field that mirrors the owner's user plan
  # The authoritative plan is stored on the User model
  PLANS = User::PLANS

  # Associations
  has_many :branches,           dependent: :destroy
  has_many :memberships,        dependent: :destroy
  has_many :users,              through: :memberships
  has_many :invitations,        dependent: :destroy
  has_many :product_categories, dependent: :destroy
  has_many :products,           dependent: :destroy
  has_many :price_lists,        dependent: :destroy
  has_many :prepayment_skus,    dependent: :destroy
  has_many :audit_logs,         dependent: :destroy
  has_many :customers,          dependent: :destroy
  has_many :sales_orders,       dependent: :destroy
  has_many :sales_invoices,     dependent: :destroy
  has_one  :credit_policy,      dependent: :destroy

  # Accounting
  has_many :accounting_integrations,  dependent: :destroy
  has_many :accounting_sync_records,  dependent: :destroy
  has_many :accounting_export_files,  dependent: :destroy

  # Billing
  has_many :subscriptions,  dependent: :destroy
  has_many :billing_events, dependent: :destroy

  BILLING_STATUSES = %w[inactive trialing active past_due cancelled].freeze

  # Validations
  validates :name,          presence: true, length: { maximum: 100 }
  validates :slug,          presence: true, uniqueness: true,
                            format: { with: /\A[a-z0-9\-]+\z/, message: 'only lowercase letters, numbers, and hyphens' }
  validates :plan,          presence: true, inclusion: { in: PLANS }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :gst_number,    format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\z/ },
                            allow_blank: true

  # Scopes
  scope :active, -> { where(active: true) }

  # Settings helpers
  def setting(key, default: nil)
    settings.fetch(key.to_s, default)
  end

  def update_setting!(key, value)
    settings_will_change!
    update!(settings: settings.merge(key.to_s => value))
  end

  # ── Billing helpers ────────────────────────────────────────────────────────

  def billing_active?
    billing_status == "active"
  end

  def billing_past_due?
    billing_status == "past_due"
  end

  def on_free_plan?
    plan == "free"
  end

  def current_subscription
    subscriptions.current.first
  end

  def activate_billing!(plan_name: nil)
    update_attrs = { billing_status: "active" }
    update_attrs[:plan] = plan_name if plan_name.present?
    update!(update_attrs)
  end

  # ── GST Configuration (Three-Tier) ────────────────────────────────────────
  # TIER 1: Organization-level IRP API credentials
  # TIER 2: State-level GSTIN registration
  # TIER 3: Branch-level GSTIN overrides (in Branch model)

  def gst_credentials_configured?
    settings.dig("gst_credentials", "irp_username").present? &&
      settings.dig("gst_credentials", "irp_password").present?
  end

  def gst_irp_username
    settings.dig("gst_credentials", "irp_username")
  end

  def gst_irp_password
    settings.dig("gst_credentials", "irp_password")
  end

  def gst_irp_environment
    settings.dig("gst_credentials", "irp_environment") || "sandbox"
  end

  # TIER 2: State-level GSTIN registrations
  def gst_state_registrations
    settings.dig("gst_state_registrations") || {}
  end

  def gst_for_state(state_code)
    gst_state_registrations.dig(state_code.to_s, "gstin")
  end

  def gstin_for_branch(branch)
    # Three-tier lookup: override > state > org
    override_gstin = branch.gst_override_gstin
    return override_gstin if override_gstin.present?

    state_gstin = gst_for_state(branch.state_code)
    return state_gstin if state_gstin.present?

    gst_number
  end

  # Callbacks
  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  private

  def generate_slug
    self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '') if name.present?
  end
end
