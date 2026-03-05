class PaymentPolicy < ApplicationPolicy
  # ── Actions ───────────────────────────────────────────────────────────────────

  # All org members can list payments
  def index? = member?

  # All org members can view a payment
  def show?  = member? && within_org?

  # Manager+ can record a payment
  def create?  = manager_above? && within_org?
  def update?  = manager_above? && within_org? && record.draft?

  # Manager+ can confirm a draft payment
  def confirm? = manager_above? && within_org? && record.draft?

  # Owner/admin only can reverse a confirmed payment (destructive)
  def reverse? = owner_or_admin? && within_org? && record.confirmed?

  # ── Scope ─────────────────────────────────────────────────────────────────────

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.for_org(organization)
      return base if manager_above?

      base.where(branch_id: membership&.branch_id)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
