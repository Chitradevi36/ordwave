class ReturnRequestPolicy < ApplicationPolicy
  # All org members can view returns
  def index?  = member?
  def show?   = member?

  # Sales reps (any member) can create draft returns and submit
  def create? = member?
  def update? = member? && record.draft?
  def submit? = member? && record.draft?

  # Warehouse and above can perform QC
  def start_qc?    = warehouse_above? && record.submitted?
  def complete_qc? = warehouse_above? && record.qc_in_progress?

  # Managers and above can cancel (draft or submitted)
  def cancel? = manager_above? && record.cancellable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.for_org(organization).not_deleted
    end
  end

  private

  # owner / admin / manager / warehouse
  def warehouse_above?
    role_name.in?(%w[owner admin manager warehouse_staff])
  end
end
