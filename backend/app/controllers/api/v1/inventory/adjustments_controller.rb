module Api
  module V1
    module Inventory
      class AdjustmentsController < BaseController
        before_action :require_organization!

        # POST /api/v1/inventory/adjustments
        # Body: { product_id, branch_id, direction, quantity, reason_code, notes }
        def create
          authorize :inventory_adjustment, :create?

          product = current_organization.products.find(adjustment_params[:product_id])
          branch  = current_organization.branches.find(
            adjustment_params[:branch_id] || current_branch&.id
          )

          result = Inventory::Adjustment.call(
            org:         current_organization,
            branch:      branch,
            product:     product,
            direction:   adjustment_params[:direction]&.to_sym,
            quantity:    adjustment_params[:quantity].to_d,
            reason_code: adjustment_params[:reason_code],
            notes:       adjustment_params[:notes],
            actor:       current_user
          )

          if result.success?
            render_created({
              message:  'Adjustment posted successfully',
              movement: serialize_movement(result.movement)
            })
          else
            render_errors(result.errors)
          end
        end

        private

        def adjustment_params
          params.require(:adjustment).permit(
            :product_id, :branch_id, :direction, :quantity, :reason_code, :notes
          )
        end

        def serialize_movement(m)
          {
            id:            m.id,
            movement_type: m.movement_type,
            direction:     m.direction,
            product_id:    m.product_id,
            branch_id:     m.branch_id,
            qty:           m.qty,
            unit_cost:     m.unit_cost,
            metadata:      m.metadata,
            occurred_at:   m.occurred_at
          }
        end
      end
    end
  end
end
