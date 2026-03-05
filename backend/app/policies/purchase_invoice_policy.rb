class PurchaseInvoicePolicy < ApplicationPolicy
  # Any org member can list/view (needed for reporting and supplier detail)
  def index?  = member?
  def show?   = member?

  # Only finance+ can create/edit/post/cancel
  def create?  = finance_above?
  def update?  = finance_above?
  def destroy? = finance_above?
  def post?    = finance_above?
  def cancel?  = finance_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
        .not_deleted
        .joins(:organization)
        .where(organization_id: organization.id)
    end
  end

  private

  def finance_above?
    role_name.in?(%w[owner admin manager accountant])
  end
end
