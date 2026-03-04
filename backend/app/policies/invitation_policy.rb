class InvitationPolicy < ApplicationPolicy
  def index?   = owner_or_admin?
  def create?  = owner_or_admin?
  def destroy? = owner_or_admin?

  # Public endpoint — no auth required for accept
  def accept?  = true

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization)
    end
  end
end
