class PickListPolicy < ApplicationPolicy
  def index?      = member?
  def show?       = member? && within_org?
  def create?     = manager_above? && within_org?
  def update?     = member? && within_org?    # warehouse staff can pick
  def start?      = member? && within_org?
  def complete?   = member? && within_org?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.where(organization: organization)
      return base if manager_above?

      # Warehouse / sales reps — scoped to their branch
      base.where(branch_id: membership&.branch_id)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
