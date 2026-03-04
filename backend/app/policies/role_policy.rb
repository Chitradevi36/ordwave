class RolePolicy < ApplicationPolicy
  # Roles are system-wide; any authenticated user can view them
  def index? = @user.present?
  def show?  = @user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
