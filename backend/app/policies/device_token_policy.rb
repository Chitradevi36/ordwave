class DeviceTokenPolicy < ApplicationPolicy
  # Any authenticated member can register their own device token
  def create?  = member?
  def destroy? = member? && own_token?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless member?
      scope.where(user: @user, organization: @organization)
    end
  end

  private

  def own_token?
    record.user_id == @user&.id
  end
end
