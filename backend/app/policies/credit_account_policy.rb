class CreditAccountPolicy < ApplicationPolicy
  def show?   = member?
  def update? = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
