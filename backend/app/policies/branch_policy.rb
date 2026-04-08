class BranchPolicy < ApplicationPolicy
  def index?           = member?
  def show?            = member?
  def create?          = manager_above?
  def update?          = manager_above?
  def bulk_import?     = manager_above?
  def update_settings? = owner_or_admin?

  # GST Registrations (TIER 2, 3)
  def manage_gst_registrations? = owner_or_admin?
  def update_gst_registration?  = owner_or_admin?
  def view_gst_registration?    = member?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: organization, deleted_at: nil)
    end
  end
end
