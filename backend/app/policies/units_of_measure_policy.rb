class UnitsOfMeasurePolicy < ApplicationPolicy
  # UOMs are global (not org-scoped), but access is still gated by org membership.
  def index?   = member?
  def show?    = member?
  def create?  = manager_above?
  def update?  = manager_above?
  def destroy? = owner_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
