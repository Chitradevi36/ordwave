class InventoryLevelPolicy < ApplicationPolicy
  def index? = member?
  def show?  = member?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
