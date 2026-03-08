# frozen_string_literal: true

# Policy for AccountingMapping.
#
# Mappings define how OMS ledger names map to Tally/provider ledger names.
# They live within an integration and are managed by owner/admin only.
class AccountingMappingPolicy < ApplicationPolicy
  def index?   = owner_or_admin?
  def show?    = owner_or_admin? && belongs_to_organization?
  def create?  = owner_or_admin?
  def update?  = owner_or_admin? && belongs_to_organization?
  def destroy? = owner_or_admin? && belongs_to_organization?

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
