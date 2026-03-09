class SalesInvoicePolicy < ApplicationPolicy
  # ── Actions ───────────────────────────────────────────────────────────────

  # All org members can view the invoice list
  def index? = member?

  # All org members can view individual invoices
  def show?  = member? && within_org?

  # Accounts + manager + owner can create invoices
  def create? = manager_above? && within_org?

  # Issue a draft invoice → accounts + manager + owner
  def issue? = manager_above? && within_org? && record.draft?

  # Void an issued invoice → owner/admin only (destructive)
  def void? = owner_or_admin? && within_org? && record.issued?

  # Download PDF → all members (just viewing)
  def pdf? = member? && within_org?

  # Generate from a specific order/stop → accounts + manager + owner
  def generate_from_order? = manager_above? && within_org?
  def generate_from_stop?  = manager_above? && within_org?

  # Generate IRN via NIC IRP → accounts + manager + owner, invoice must be issued
  def einvoice? = manager_above? && within_org? && record.issued?

  # Generate e-waybill → accounts + manager + owner, invoice must be issued
  def ewaybill? = manager_above? && within_org? && record.issued?

  # Cancel e-waybill → owner/admin only
  def cancel_ewaybill? = owner_or_admin? && within_org?

  # ── Scope ────────────────────────────────────────────────────────────────

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.not_deleted.where(organization: organization)
      return base if manager_above?

      # Sales reps see only their branch's invoices
      base.where(branch_id: membership&.branch_id)
    end
  end

  private

  def within_org?
    record.organization_id == @organization&.id
  end
end
