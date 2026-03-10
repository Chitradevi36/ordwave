class SalesOrderPolicy < ApplicationPolicy
  def index?  = member?
  def show?   = member? && within_scope?

  def create?
    member? && (manager_above? || sales_rep?)
  end

  def update?
    return false unless member?

    # Draft: full edit by manager or order creator
    return manager_above? || own_order? if record.editable?

    # Submitted / on_hold: limited field edit (delivery_date, notes) by managers only
    return manager_above? if record.limited_editable?

    false
  end

  def submit?
    return false unless member?
    return false unless record.draft?

    manager_above? || own_order?
  end

  def approve?
    return false unless member?
    manager_above?
  end

  def hold?
    return false unless member?
    manager_above?
  end

  def cancel?
    return false unless member?
    return false unless record.cancellable?

    # Approved orders — only manager_above can cancel
    return manager_above? if record.approved?

    manager_above? || own_order?
  end

  def refresh_price?
    return false unless member?
    return false unless record.draft?

    manager_above? || own_order?
  end

  # Warehouse staff (and managers) can mark an approved order as picked
  def pick?
    return false unless member? && within_scope?
    return false unless record.pending_pick?

    warehouse_staff? || manager_above?
  end

  # Only managers and above can confirm a pick
  def confirm_pick?
    return false unless member? && within_scope?
    return false unless record.picked?

    manager_above?
  end

  def from_mobile?
    member? && (manager_above? || sales_rep?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = @scope.not_deleted.where(organization_id: @organization.id)

      if role_name.in?(%w[owner admin])
        base
      elsif role_name == 'manager'
        membership = @user.membership_for(@organization)
        base.where(branch_id: membership&.branch_id)
      elsif role_name == 'sales_rep'
        base.by_created_by(@user.id)
      elsif role_name == 'warehouse_staff'
        membership = @user.membership_for(@organization)
        base.where(branch_id: membership&.branch_id)
             .where.not(status: %w[draft cancelled rejected])
      else
        base.none
      end
    end

    private

    def role_name
      @user.membership_for(@organization)&.role&.name
    end
  end

  private

  def own_order?
    record.created_by_id == @user.id
  end

  def sales_rep?
    role_name == 'sales_rep'
  end

  def warehouse_staff?
    role_name == 'warehouse_staff'
  end

  def within_scope?
    SalesOrderPolicy::Scope.new(user_context, SalesOrder).resolve.exists?(record.id)
  end
end
