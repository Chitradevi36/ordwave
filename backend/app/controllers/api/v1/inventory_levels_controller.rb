module Api
  module V1
    class InventoryLevelsController < BaseController
      before_action :require_organization!

      # GET /api/v1/inventory_levels
      def index
        scope = InventoryLevel.where(organization: current_organization)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?

        levels = paginate(scope.includes(:branch, :product).order('products.name ASC'))

        render_success(
          levels.map { |l| serialize_level(l) },
          meta: pagination_meta(levels)
        )
      end

      # GET /api/v1/inventory_levels/:id
      def show
        level = InventoryLevel.where(organization: current_organization).find(params[:id])
        authorize level
        render_success(serialize_level(level))
      end

      private

      def serialize_level(level)
        {
          id:            level.id,
          branch_id:     level.branch_id,
          branch_name:   level.branch&.name,
          product_id:    level.product_id,
          product_name:  level.product&.name,
          product_sku:   level.product&.sku,
          qty_on_hand:   level.qty_on_hand,
          qty_reserved:  level.qty_reserved,
          qty_available: level.qty_available,
          updated_at:    level.updated_at
        }
      end
    end
  end
end
