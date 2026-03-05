class SupplierProductPolicy < ApplicationPolicy
  def index?   = member?
  def show?    = member?
  def create?  = finance_above?
  def update?  = finance_above?
  def destroy? = finance_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:supplier).where(suppliers: { organization: organization, deleted_at: nil })
    end
  end

  private

  def finance_above?
    role_name.in?(%w[owner admin manager accountant])
  end
end
