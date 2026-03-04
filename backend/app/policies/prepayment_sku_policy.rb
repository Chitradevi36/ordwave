class PrepaymentSkuPolicy < ApplicationPolicy
  def index?   = manager_above?
  def show?    = manager_above?
  def create?  = owner_or_admin? || manager?
  def update?  = owner_or_admin? || manager?
  def destroy? = owner_or_admin? || manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
