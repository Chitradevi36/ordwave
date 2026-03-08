# Shared validation concern for AccountingExportFile, AccountingSyncRecord,
# and AccountingMapping.
#
# Any model that belongs_to :accounting_integration and :organization can include
# this to get cross-record consistency checks.
#
# Usage:
#   include AccountingTenantValidatable
#
# Requires the including model to:
#   - belong_to :accounting_integration
#   - belong_to :organization
module AccountingTenantValidatable
  extend ActiveSupport::Concern

  included do
    validate :provider_matches_integration,      if: :accounting_integration
    validate :organization_matches_integration,  if: :accounting_integration
  end

  private

  def provider_matches_integration
    return if provider.blank?
    return if accounting_integration.blank?

    unless provider == accounting_integration.provider
      errors.add(:provider, "must match the integration provider (#{accounting_integration.provider})")
    end
  end

  def organization_matches_integration
    return if organization.blank?
    return if accounting_integration.blank?

    unless organization_id == accounting_integration.organization_id
      errors.add(:organization, "must match the integration's organization")
    end
  end
end
