class MembershipPolicy < ApplicationPolicy
  def index?   = member?
  def create?  = owner_or_admin?
  def destroy? = owner_or_admin? || own_membership?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization, deleted_at: nil)
    end
  end

  private

  def own_membership?
    @record.user == @user
  end
end
