class CreditNotePolicy < ApplicationPolicy
  # All org members can view credit notes
  def index? = member?
  def show?  = member?

  # Managers and above (accounts/finance) can issue credit notes
  def issue? = manager_above?

  # Only owner can void a credit note
  def void? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.for_org(organization).not_deleted
    end
  end
end
