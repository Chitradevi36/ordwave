class DeliveryTripPolicy < ApplicationPolicy
  def index?    = member?
  def show?     = member? && within_org?
  def create?   = manager_above?
  def update?   = manager_above? && within_org?
  def dispatch? = manager_above? && within_org?
  def cancel?   = manager_above? && within_org?
  def complete? = member? && within_org?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.where(organization: organization)
      return base if manager_above?

      # Warehouse staff / sales rep — only see their branch's trips
      base.where(branch_id: membership&.branch_id)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
