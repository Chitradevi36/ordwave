class TripStopPolicy < ApplicationPolicy
  def index?    = member?
  def show?     = member? && within_org?
  def create?   = manager_above?
  def update?   = manager_above? && within_org?
  def complete? = member? && within_org?   # driver/warehouse can complete

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:delivery_trip).where(delivery_trips: { organization: organization })
    end
  end

  private

  def within_org?
    record.delivery_trip.organization_id == @organization&.id
  end
end
