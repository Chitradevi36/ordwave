class PriceListPolicy < ApplicationPolicy
  def index?   = member?
  def show?    = member?
  def create?  = manager_above?
  def update?  = manager_above?
  def destroy? = manager_above?
  def assign?  = manager_above?
  def unassign? = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted.where(organization: organization)
    end
  end
end
