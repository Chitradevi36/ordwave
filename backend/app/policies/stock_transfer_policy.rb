class StockTransferPolicy < ApplicationPolicy
  # All org members can list and view transfers
  def index?  = member?
  def show?   = member?

  # Warehouse managers and above can create, edit, dispatch, receive
  def create?   = warehouse_above?
  def update?   = warehouse_above?
  def dispatch? = warehouse_above?
  def receive?  = warehouse_above?

  # Managers and above can cancel
  def cancel? = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
        .for_org(organization)
    end
  end

  private

  # owner / admin / manager / warehouse
  def warehouse_above?
    role_name.in?(%w[owner admin manager warehouse_staff])
  end
end
