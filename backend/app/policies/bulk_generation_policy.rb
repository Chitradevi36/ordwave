class BulkGenerationPolicy < ApplicationPolicy
  # ── Actions ───────────────────────────────────────────────────────────────────

  # Manager+ can view bulk generation status
  def index? = manager_above?

  # Manager+ can view detailed status of a bulk generation
  def show?  = manager_above? && within_org?

  # Manager+ can initiate bulk invoice generation
  def create? = manager_above? && within_org?

  # Manager+ can cancel a bulk generation in progress
  def cancel? = manager_above? && within_org? && record.in_progress?

  # ── Scope ─────────────────────────────────────────────────────────────────────

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.for_org(organization)
      return base if manager_above?

      base.where(created_by_id: user&.id)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
