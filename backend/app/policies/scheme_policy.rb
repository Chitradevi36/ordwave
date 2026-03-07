class SchemePolicy < ApplicationPolicy
  def index?      = member?
  def show?       = member?
  def by_product? = member?
  def stats?      = member?
  def create?     = manager_above?
  def update?     = manager_above?
  def destroy?    = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
