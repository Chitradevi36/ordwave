module Api
  module V1
    module Inventory
      class MovementsController < BaseController
        before_action :require_organization!

        # GET /api/v1/inventory/movements
        # Filters: branch_id, product_id, movement_type, date_from, date_to, reference_type
        def index
          scope = policy_scope(StockMovement)
            .includes(:product, :branch, :created_by)
            .where(organization: current_organization)

          scope = scope.where(branch_id: params[:branch_id])         if params[:branch_id].present?
          scope = scope.where(product_id: params[:product_id])       if params[:product_id].present?
          scope = scope.where(movement_type: params[:movement_type]) if params[:movement_type].present?
          scope = scope.where(reference_type: params[:reference_type]) if params[:reference_type].present?
          scope = scope.in_date_range(params[:date_from], params[:date_to])

          movements = paginate(scope.recent)

          render_success(
            movements.map { |m| serialize_movement(m) },
            meta: pagination_meta(movements)
          )
        end

        private

        def serialize_movement(m)
          {
            id:                m.id,
            movement_type:     m.movement_type,
            direction:         m.direction,
            product_id:        m.product_id,
            product_name:      m.product.name,
            sku:               m.product.sku,
            branch_id:         m.branch_id,
            branch_name:       m.branch.name,
            qty:               m.qty,
            unit_cost:         m.unit_cost,
            on_hand_delta:     m.on_hand_delta,
            reference_type:    m.reference_type,
            reference_id:      m.reference_id,
            reference_line_id: m.reference_line_id,
            notes:             m.notes,
            metadata:          m.metadata,
            occurred_at:       m.occurred_at,
            created_by_id:     m.created_by_id,
            created_by_name:   m.created_by&.full_name
          }
        end
      end
    end
  end
end
