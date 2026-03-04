class OrganizationPolicy < ApplicationPolicy
  # index — list orgs this user is a member of (no org context required)
  def index?           = true
  def show?            = member_of_record?
  def create?          = @user.present?   # any authenticated user can create an org
  def update?          = member_of_record? && owner_or_admin_of_record?
  def update_settings? = member_of_record? && owner_or_admin_of_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Return all active orgs the user has an active membership in
      Organization.active
                  .joins(:memberships)
                  .where(memberships: { user: user, deleted_at: nil, active: true })
                  .distinct
    end
  end

  private

  # For organization actions, the "record" IS the organization being operated on.
  # We check membership against the record directly (not current_organization,
  # which may be nil when creating/listing).
  def membership_on_record
    @membership_on_record ||= @user&.memberships&.active&.find_by(organization: @record)
  end

  def member_of_record?
    membership_on_record.present?
  end

  def owner_or_admin_of_record?
    membership_on_record&.role&.name&.in?(%w[owner admin])
  end
end
