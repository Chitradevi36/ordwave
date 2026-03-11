# frozen_string_literal: true

class GstReturnPeriodPolicy < ApplicationPolicy
  # Any authenticated member of the org can view periods
  def index?  = true
  def show?   = true

  # Locking, filing, reopening require manager or above
  def lock?   = manager_or_owner?
  def file?   = manager_or_owner?
  def reopen? = manager_or_owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: user.organization_ids)
    end
  end

  private

  def manager_or_owner?
    user.role.in?(%w[owner admin manager])
  rescue NoMethodError
    false
  end
end
