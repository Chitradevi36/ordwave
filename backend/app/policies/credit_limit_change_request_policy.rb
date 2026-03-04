class CreditLimitChangeRequestPolicy < ApplicationPolicy
  # Manager, accountant, admin can create requests
  def index?    = member?
  def show?     = member?
  def create?   = role_name.in?(%w[owner admin manager accountant])
  # Only owner can decide
  def decision? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:credit_account).where(credit_accounts: { organization_id: organization.id })
    end
  end
end
