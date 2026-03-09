class AccountingIntegration < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :organization
  belongs_to :connected_by, class_name: "User", optional: true

  has_many :accounting_sync_records,  dependent: :restrict_with_error
  has_many :accounting_export_files,  dependent: :restrict_with_error
  has_many :accounting_mappings,      dependent: :destroy
  has_many :accounting_agents,        dependent: :destroy

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum provider: {
    tally:       "tally",
    zoho_books:  "zoho_books",
    busy:        "busy",
    marg:        "marg",
    vyapar:      "vyapar",
    cleartax:    "cleartax"
  }, _prefix: :provider

  enum status: {
    disconnected: "disconnected",
    connected:    "connected",
    error:        "error",
    disabled:     "disabled"
  }, _prefix: :status

  enum sync_mode: {
    batch_export:    "batch_export",
    realtime_agent:  "realtime_agent"
  }, _prefix: :sync_mode

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :organization,  presence: true
  validates :provider,      presence: true,
                            inclusion: { in: providers.keys }
  validates :status,        presence: true,
                            inclusion: { in: statuses.keys }
  validates :sync_mode,     presence: true,
                            inclusion: { in: sync_modes.keys }
  validates :provider,      uniqueness: { scope: :organization_id,
                                          message: "already has an integration for this provider" }

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :normalize_string_fields
  before_validation :ensure_config_json_hash

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :active,          -> { where(status: %w[connected error]) }
  scope :connected_only,  -> { where(status: "connected") }
  scope :by_provider,     ->(prov) { where(provider: prov) }
  scope :recently_synced, -> { where.not(last_synced_at: nil).order(last_synced_at: :desc) }

  # ---------------------------------------------------------------------------
  # Typed config accessors (all values live in config_json jsonb column)
  # ---------------------------------------------------------------------------
  CONFIG_FIELDS = %w[
    tally_host
    tally_port
    company_name
    financial_year
    narration_template
    round_off_ledger
    default_sales_ledger
    default_purchase_ledger
    retailers_group_name
    suppliers_group_name
    cgst_output_ledger
    sgst_output_ledger
    igst_output_ledger
    cgst_input_ledger
    sgst_input_ledger
    igst_input_ledger
  ].freeze

  CONFIG_FIELDS.each do |field|
    define_method(field) do
      config_json[field]
    end

    define_method(:"#{field}=") do |value|
      self.config_json = config_json.merge(field => value.is_a?(String) ? value.strip : value)
    end
  end

  # Generic key/value helpers for programmatic access
  def config_value(key)
    config_json[key.to_s]
  end

  def set_config_value(key, value)
    self.config_json = config_json.merge(key.to_s => value)
  end

  # ---------------------------------------------------------------------------
  # Status helpers
  # ---------------------------------------------------------------------------

  # Avoid conflicting with enum-generated `error?` predicate — use `errored?`
  def errored?
    status_error?
  end

  def active_for_sync?
    status_connected? && !disabled?
  end

  def mark_error!(message)
    update!(status: "error", last_error_at: Time.current, last_error_message: message)
  end

  def mark_connected!
    update!(status: "connected", last_error_at: nil, last_error_message: nil)
  end

  def mark_disconnected!
    update!(status: "disconnected")
  end

  # ---------------------------------------------------------------------------
  # Display helpers
  # ---------------------------------------------------------------------------
  PROVIDER_LABELS = {
    "tally"      => "Tally Prime",
    "zoho_books" => "Zoho Books",
    "busy"       => "Busy",
    "marg"       => "Marg",
    "vyapar"     => "Vyapar",
    "cleartax"   => "ClearTax"
  }.freeze

  def provider_name
    PROVIDER_LABELS.fetch(provider.to_s, provider.to_s.humanize)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  private

  def normalize_string_fields
    self.provider   = provider.to_s.strip.downcase   if provider.present?
    self.status     = status.to_s.strip.downcase     if status.present?
    self.sync_mode  = sync_mode.to_s.strip.downcase  if sync_mode.present?
  end

  def ensure_config_json_hash
    self.config_json = {} unless config_json.is_a?(Hash)
  end
end
