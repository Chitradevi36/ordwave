# frozen_string_literal: true

# Policy for AccountingExportFile.
#
# Export files are batch XML outputs.
# Managers and above can view and create them.
# Download is restricted to owner/admin to prevent mass data extraction.
class AccountingExportFilePolicy < ApplicationPolicy
  def index?    = manager_above?
  def show?     = manager_above? && belongs_to_organization?
  def new?      = owner_or_admin?
  def create?   = owner_or_admin?
  def download? = owner_or_admin? && belongs_to_organization?

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
