module Api
  module V1
    module Inventory
      class BalancesController < BaseController
        before_action :require_organization!

        # GET /api/v1/inventory/balances
        # Filters: branch_id, q (name/SKU search), category_id, low_stock=true
        def index
          scope = policy_scope(InventoryLevel)
            .includes(:product, :branch)
            .for_org(current_organization)

          scope = scope.for_branch(params[:branch_id]) if params[:branch_id].present?
          scope = scope.search_q(params[:q])           if params[:q].present?
          scope = scope.by_category(params[:category_id]) if params[:category_id].present?
          scope = scope.low_stock                       if params[:low_stock] == 'true'

          levels = paginate(scope.order('products.name ASC'))

          render_success(
            levels.map { |l| serialize_balance(l) },
            meta: pagination_meta(levels)
          )
        end

        # GET /api/v1/inventory/balances/:id
        def show
          level = InventoryLevel
            .includes(:product, :branch)
            .for_org(current_organization)
            .find(params[:id])

          authorize level
          render_success(serialize_balance(level, detailed: true))
        end

        private

        def serialize_balance(level, detailed: false)
          {
            id:                level.id,
            product_id:        level.product_id,
            product_name:      level.product.name,
            sku:               level.product.sku,
            branch_id:         level.branch_id,
            branch_name:       level.branch.name,
            qty_on_hand:       level.qty_on_hand,
            qty_reserved:      level.qty_reserved,
            qty_available:     level.qty_on_hand - level.qty_reserved,
            min_qty_threshold: level.min_qty_threshold,
            low_stock:         level.low_stock?,
            updated_at:        level.updated_at
          }
        end
      end
    end
  end
end
