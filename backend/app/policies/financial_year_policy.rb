# frozen_string_literal: true

class FinancialYearPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = manager_or_owner?
  def lock?    = manager_or_owner? && !record.closed?
  def close?   = manager_or_owner? && !record.closed?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: user.organization_ids)
    end
  end

  private

  def manager_or_owner?
    user.owner? || user.admin? || user.manager?
  rescue NoMethodError
    user.role.in?(%w[owner admin manager])
  end
end
