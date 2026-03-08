# frozen_string_literal: true

# Policy for AccountingSyncRecord.
#
# Sync records are generated automatically by the system.
# Operators (owner/admin/manager) can view them.
# Only owner/admin may trigger manual retries.
class AccountingSyncRecordPolicy < ApplicationPolicy
  # All managers and above can browse the sync dashboard
  def index?  = manager_above?

  # All managers and above can view a sync record detail
  def show?   = manager_above? && belongs_to_organization?

  # Manual retry is owner/admin only (it will enqueue a background job)
  def retry?  = owner_or_admin? && belongs_to_organization?

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
