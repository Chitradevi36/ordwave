class UserPolicy < ApplicationPolicy
  # Shows users who are members of the current organization
  def index?           = member?
  def show?            = member? || own_record?
  def create?          = owner_or_admin?
  def update?          = owner_or_admin? || own_record?
  def invite?          = owner_or_admin?
  def deactivate?      = owner_or_admin?
  def change_password? = own_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:memberships)
           .where(memberships: { organization: organization, deleted_at: nil, active: true })
           .distinct
    end
  end

  private

  def own_record?
    @record == @user
  end
end
