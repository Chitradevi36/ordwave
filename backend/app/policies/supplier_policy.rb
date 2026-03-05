class SupplierPolicy < ApplicationPolicy
  # Any org member can list/view suppliers (needed for PO creation dropdowns)
  def index?   = member?
  def show?    = member?

  # Only manager and above (+ accountant) can mutate supplier master data
  def create?  = finance_above?
  def update?  = finance_above?
  def destroy? = finance_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted.where(organization: organization)
    end
  end

  private

  # Extends manager_above? to also include accountants per FRD §10 access rules.
  def finance_above?
    role_name.in?(%w[owner admin manager accountant])
  end
end
