class CustomerPolicy < ApplicationPolicy
  def index?        = member?
  def show?         = member?
  def create?       = manager_above?
  def update?       = manager_above?
  def destroy?      = manager_above?
  def block?        = manager_above?
  def unblock?      = manager_above?
  def deactivate?   = manager_above?
  def bulk_import?  = manager_above?
  # Credit usage is visible to any org member with branch access.
  def credit_usage? = member?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.not_deleted.where(organization: organization)
      return base if role_name.in?(%w[owner admin manager])

      # Sales reps / members only see customers assigned to their branch's routes
      member_branch_id = membership&.branch_id
      return base.none unless member_branch_id

      route_ids = Route.where(branch_id: member_branch_id, active: true).pluck(:id)
      base.where(branch_id: member_branch_id).or(base.where(route_id: route_ids))
    end

    private

    def membership
      @membership ||= @user.membership_for(@organization)
    end

    def role_name
      membership&.role&.name
    end
  end
end
