class BeatSchedulePolicy < ApplicationPolicy
  def index?        = member?
  def show?         = member?
  def retailers?    = member?
  def create?       = manager_above?
  def update?       = manager_above?
  def bulk_upsert?  = manager_above?
  def destroy?      = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.active.where(organization: organization)
    end
  end
end
