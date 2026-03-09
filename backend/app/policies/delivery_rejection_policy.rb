# frozen_string_literal: true

class DeliveryRejectionPolicy < ApplicationPolicy
  def index?  = member?
  def show?   = member?
  def create? = manager_above? && within_org?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(trip_stop: { delivery_trip: :branch })
           .where(branches: { organization_id: organization.id })
    end
  end

  private

  def within_org?
    record.trip_stop&.delivery_trip&.branch&.organization_id == @organization.id
  end
end
