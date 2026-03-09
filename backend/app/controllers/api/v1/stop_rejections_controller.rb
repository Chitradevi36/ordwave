# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/delivery_trips/:delivery_trip_id/trip_stops/:trip_stop_id/rejections
    #
    # Records one or more product rejections at a delivery stop.
    # When auto_return is true (default), a ReturnRequest is automatically
    # created for the rejected items.
    class StopRejectionsController < BaseController
      before_action :require_organization!
      before_action :set_trip_stop

      # POST .../rejections
      def create
        authorize DeliveryRejection.new(
          trip_stop:   @trip_stop,
          sales_order: @trip_stop.sales_order
        ), :create?

        rejection_attrs = rejection_params.to_h.symbolize_keys.merge(
          trip_stop:   @trip_stop,
          sales_order: @trip_stop.sales_order,
          rejected_by: current_user
        )

        rejection = nil

        ActiveRecord::Base.transaction do
          rejection = DeliveryRejection.create!(rejection_attrs)

          if rejection.auto_return?
            return_request = create_auto_return(rejection)
            rejection.update_column(:return_request_id, return_request.id) if return_request
          end
        end

        render_created(serialize_rejection(rejection))
      rescue ActiveRecord::RecordInvalid => e
        render_errors(e.record.errors.full_messages)
      end

      private

      def set_trip_stop
        delivery_trip = DeliveryTrip.joins(:branch)
                                    .where(branches: { organization_id: current_organization.id })
                                    .find(params[:delivery_trip_id])

        @trip_stop = delivery_trip.trip_stops.find(params[:trip_stop_id])
      end

      def rejection_params
        # Accept both flat { product_id: ... } and nested { rejection: { product_id: ... } }
        if params[:rejection].present?
          params.require(:rejection).permit(
            :product_id, :qty_rejected, :reason_code, :condition, :notes, :auto_return
          )
        else
          params.permit(
            :product_id, :qty_rejected, :reason_code, :condition, :notes, :auto_return
          )
        end
      end

      # Creates a ReturnRequest for the rejected line automatically.
      def create_auto_return(rejection)
        return nil unless defined?(ReturnRequest)

        ReturnRequest.create!(
          organization:  current_organization,
          branch:        @trip_stop.delivery_trip.branch,
          customer:      @trip_stop.sales_order.customer,
          sales_order:   @trip_stop.sales_order,
          trip_stop:     @trip_stop,
          requested_by:  current_user,
          reason:        rejection.reason_code,
          status:        'pending',
          lines_attributes: [
            {
              product_id: rejection.product_id,
              qty:        rejection.qty_rejected,
              reason:     rejection.reason_code,
              condition:  rejection.condition
            }
          ]
        )
      rescue StandardError => e
        Rails.logger.error("[StopRejectionsController] auto_return failed: #{e.message}")
        nil
      end

      def serialize_rejection(r)
        {
          id:                r.id,
          trip_stop_id:      r.trip_stop_id,
          sales_order_id:    r.sales_order_id,
          product_id:        r.product_id,
          product_name:      r.product.name,
          qty_rejected:      r.qty_rejected,
          reason_code:       r.reason_code,
          condition:         r.condition,
          notes:             r.notes,
          auto_return:       r.auto_return,
          return_request_id: r.return_request_id,
          rejected_by:       { id: r.rejected_by_id, name: r.rejected_by.full_name },
          created_at:        r.created_at
        }
      end
    end
  end
end
