# frozen_string_literal: true

# Policy for AccountingIntegration.
#
# Role hierarchy (from ApplicationPolicy):
#   owner?          → role == "owner"
#   admin?          → role == "admin"
#   manager?        → role == "manager"
#   owner_or_admin? → owner || admin
#   manager_above?  → owner || admin || manager
#
# Integration configuration and status management is restricted to
# owners and admins. Managers and above may view.
class AccountingIntegrationPolicy < ApplicationPolicy
  # All org members in manager role or above can view the list
  def index?  = manager_above?

  # Any member at manager-level or above can view integration details
  def show?   = manager_above? && belongs_to_organization?

  # Only owner/admin can create a new integration
  def create? = owner_or_admin?

  # Only owner/admin can edit configuration
  def edit?   = owner_or_admin? && belongs_to_organization?

  # Only owner/admin can save configuration updates
  def update? = owner_or_admin? && belongs_to_organization?

  # Validate configuration settings (non-destructive action)
  def test_configuration? = owner_or_admin? && belongs_to_organization?

  # Status mutation actions
  def mark_connected?    = owner_or_admin? && belongs_to_organization?
  def mark_disconnected? = owner_or_admin? && belongs_to_organization?

  # Read-only agent monitoring (managers and above)
  def agents?      = manager_above? && belongs_to_organization?
  def queue_stats? = manager_above? && belongs_to_organization?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end

  private

  def belongs_to_organization?
    record.organization_id == @organization&.id
  end
end
