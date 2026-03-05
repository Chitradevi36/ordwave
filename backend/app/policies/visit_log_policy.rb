class VisitLogPolicy < ApplicationPolicy
  # Any member can list / show. The Scope narrows to own records for sales reps.
  def index?  = member?
  def show?   = member? && (own_record? || manager_above?)
  def create? = member?
  def update? = own_record? || manager_above?
  def skip?   = own_record? || manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if manager_above?
        scope.where(organization: organization)
      else
        scope.where(organization: organization, sales_rep_id: user.id)
      end
    end
  end

  private

  def own_record?
    record.sales_rep_id == user.id
  end
end
