class HsnSacCodePolicy < ApplicationPolicy
  # HSN/SAC master data is organization-agnostic (global catalogue).
  # Managers and above can read; only owners/admins can mutate.

  def index?        = manager_above?
  def show?         = manager_above?
  def lookup?       = manager_above?    # GET /lookup collection action
  def create?       = owner_or_admin?
  def update?       = owner_or_admin?
  def destroy?      = owner_or_admin?
  def rate_change?  = owner_or_admin?
  def bulk_import?  = owner_or_admin?

  class Scope < ApplicationPolicy::Scope
    # Global master — not scoped per organisation
    def resolve
      scope.all
    end
  end
end
