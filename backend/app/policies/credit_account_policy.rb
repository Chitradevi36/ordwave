class CreditAccountPolicy < ApplicationPolicy
  def show?         = member?
  def update?       = manager_above?
  def update_flags? = owner_or_admin? || manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
