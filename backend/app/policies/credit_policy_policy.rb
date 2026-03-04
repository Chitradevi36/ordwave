class CreditPolicyPolicy < ApplicationPolicy
  # Only owner/admin can view or edit credit policy
  def show?   = owner_or_admin?
  def update? = owner_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
