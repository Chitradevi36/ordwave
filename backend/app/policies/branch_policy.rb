class BranchPolicy < ApplicationPolicy
  def index?   = member?
  def show?    = member?
  def create?  = manager_above?
  def update?  = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization, deleted_at: nil)
    end
  end
end
