class WebhookEndpointPolicy < ApplicationPolicy
  # Only owners and admins can manage webhooks
  def index?   = owner_or_admin?
  def show?    = owner_or_admin?
  def create?  = owner_or_admin?
  def update?  = owner_or_admin?
  def destroy? = owner_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless member?
      scope.where(organization: @organization)
    end
  end
end
