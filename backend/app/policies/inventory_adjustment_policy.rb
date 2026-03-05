# Headless policy used for manual stock adjustments.
# Only managers and above (owner / admin / manager) may create adjustments.
# Usage in controller: authorize :inventory_adjustment, :create?
#
class InventoryAdjustmentPolicy < ApplicationPolicy
  def create? = manager_above?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.none
  end
end
