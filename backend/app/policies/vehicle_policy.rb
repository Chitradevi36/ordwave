class VehiclePolicy < ApplicationPolicy
  def index?   = member?
  def show?    = member? && within_org?
  def create?  = manager_above?
  def update?  = manager_above? && within_org?
  def destroy? = manager_above? && within_org?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.not_deleted.where(organization: organization)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
