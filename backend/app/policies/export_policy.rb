class ExportPolicy < ApplicationPolicy
  # Managers and above can request / view exports
  def index?  = manager_above?
  def create? = manager_above?
  def show?   = manager_above? && own_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless member?
      if @user.membership_for(@organization)&.role&.name&.in?(%w[owner admin])
        scope.where(organization: @organization)
      else
        scope.where(organization: @organization, requested_by: @user)
      end
    end
  end

  private

  def own_or_admin?
    owner_or_admin? || record.requested_by_id == @user&.id
  end
end
