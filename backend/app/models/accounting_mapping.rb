class AccountingMapping < ApplicationRecord
  include AccountingTenantValidatable

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :organization
  belongs_to :accounting_integration

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :organization,           presence: true
  validates :accounting_integration, presence: true
  validates :mapping_key,            presence: true,
                                     uniqueness: { scope: :accounting_integration_id,
                                                   message: "already set for this integration" }
  validates :mapping_value,          presence: true

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :normalize_mapping_key
  before_validation :strip_mapping_value
  before_validation :inherit_organization_from_integration

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :by_key,       ->(key) { where(mapping_key: key.to_s.strip.downcase) }
  scope :recent_first, -> { order(created_at: :desc) }

  # ---------------------------------------------------------------------------
  # Class-level lookup helpers
  # ---------------------------------------------------------------------------

  # Returns the mapping_value for a given integration + key, or default.
  # Example: AccountingMapping.fetch_value(integration, "sales_ledger", default: "Sales Account")
  def self.fetch_value(integration, key, default: nil)
    find_by(accounting_integration: integration, mapping_key: key.to_s.strip.downcase)&.mapping_value || default
  end

  # Returns all mappings for an integration as a flat hash.
  # Example: AccountingMapping.to_hash_for(integration)
  #   => { "sales_ledger" => "Sales Account @12%", "cgst_output_ledger" => "Output CGST", ... }
  def self.to_hash_for(integration)
    where(accounting_integration: integration)
      .pluck(:mapping_key, :mapping_value)
      .to_h
  end

  # ---------------------------------------------------------------------------
  # Instance helpers
  # ---------------------------------------------------------------------------
  def normalized_key
    mapping_key.to_s.strip.gsub(/[\s\-]+/, "_").downcase
  end

  def display_key
    mapping_key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  private

  def normalize_mapping_key
    self.mapping_key = normalized_key if mapping_key.present?
  end

  def strip_mapping_value
    self.mapping_value = mapping_value.strip if mapping_value.present?
  end

  def inherit_organization_from_integration
    return if accounting_integration.blank?
    self.organization = accounting_integration.organization if organization.blank?
  end
end
