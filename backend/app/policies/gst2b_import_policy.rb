# frozen_string_literal: true

class Gst2bImportPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = manager_or_owner?

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
