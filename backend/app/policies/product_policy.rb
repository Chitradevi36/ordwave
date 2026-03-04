class ProductPolicy < ApplicationPolicy
  def index?       = member?
  def show?        = member?
  def create?      = manager_above?
  def update?      = manager_above?
  def destroy?     = manager_above?
  def discontinue? = manager_above?
  def bulk_import? = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted.where(organization: organization)
    end
  end
end
