class CollectionSchedulePolicy < ApplicationPolicy
  def index?  = true
  def show?   = record.organization_id == user.current_organization_id
  def create? = member? || manager? || admin? || owner?
  def update? = record.organization_id == user.current_organization_id && (member? || manager? || admin? || owner?)

  def complete?   = update?
  def skip?       = update?
  def reschedule? = update?

  class Scope < Scope
    def resolve
      scope.for_organization(user.current_organization_id)
    end
  end
end
