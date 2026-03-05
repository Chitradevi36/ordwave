class AdvancePaymentPolicy < ApplicationPolicy
  def index?  = member?
  def show?   = member? && within_org?
  def create? = manager_above? && within_org?
  def apply?  = manager_above? && within_org? && record.applicable?
  def refund? = owner_or_admin? && within_org? && record.refundable?

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
