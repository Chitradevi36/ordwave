module Api
  module V1
    class TripStopsController < BaseController
      before_action :require_organization!
      before_action :set_trip
      before_action :set_stop, only: %i[show complete]

      # GET /api/v1/delivery_trips/:delivery_trip_id/trip_stops
      def index
        authorize TripStop.new(delivery_trip: @trip), :index?
        stops = policy_scope(TripStop).where(delivery_trip: @trip).ordered
                                      .includes({ sales_order: [:customer, { lines: :product }] }, :proof, :returns)
        render_success(stops.map { |s| serialize_stop(s, detailed: true) })
      end

      # GET /api/v1/delivery_trips/:delivery_trip_id/trip_stops/:id
      def show
        authorize @stop
        render_success(serialize_stop(@stop, detailed: true))
      end

      # POST /api/v1/delivery_trips/:delivery_trip_id/trip_stops/:id/complete
      def complete
        authorize @stop, :complete?

        result = Delivery::CompleteStopService.call(
          actor:            current_user,
          stop:             @stop,
          idempotency_key:  params[:idempotency_key],
          outcome:          stop_params[:outcome],
          delivered_lines:  stop_params[:delivered_lines] || [],
          returns:          stop_params[:returns]          || [],
          proof_type:       stop_params[:proof_type] || 'photo',
          photo:            stop_params[:photo],
          signature_image:  stop_params[:signature_image],
          otp_code:         stop_params[:otp_code],
          override_reason:  stop_params[:override_reason],
          latitude:         stop_params[:latitude],
          longitude:        stop_params[:longitude],
          device_id:        stop_params[:device_id],
          exception_code:   stop_params[:exception_code],
          delivery_notes:   stop_params[:delivery_notes]
        )

        if result[:ok]
          render_success(serialize_stop(result[:stop], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      private

      def set_trip
        @trip = policy_scope(DeliveryTrip).find(params[:delivery_trip_id])
      end

      def set_stop
        @stop = TripStop.where(delivery_trip: @trip).find(params[:id])
      end

      def stop_params
        # Support both `trip_stop: { ... }` (web/nested) and flat JSON (mobile).
        # Rails wrap_parameters can inject an empty `trip_stop: {}` — treat that
        # the same as absent by using .present? rather than .key?
        p = params[:trip_stop].present? ? params.require(:trip_stop) : params
        p.permit(
          :outcome, :proof_type, :photo, :signature_image, :otp_code,
          :override_reason, :latitude, :longitude, :device_id,
          :exception_code, :delivery_notes,
          delivered_lines: %i[sales_order_line_id delivered_qty],
          returns: %i[product_id qty_returned condition reason_code notes]
        )
      end

      # Returns a URL for an Active Storage attachment, or nil if not attached
      # or if Active Storage tables have not yet been migrated.
      def safe_attachment_url(attachment)
        attachment.attached? ? url_for(attachment) : nil
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def serialize_stop(stop, detailed: false)
        data = {
          id:             stop.id,
          sequence:       stop.sequence,
          status:         stop.status,
          exception_code: stop.exception_code,
          delivered_at:   stop.delivered_at,
          delivery_notes: stop.delivery_notes,
          latitude:       stop.latitude,
          longitude:      stop.longitude,
          sales_order: {
            id:           stop.sales_order.id,
            order_number: stop.sales_order.order_number,
            status:       stop.sales_order.status,
            total_amount: stop.sales_order.total_amount,
            customer:     {
              id:   stop.sales_order.customer_id,
              name: stop.sales_order.customer.name,
              address: stop.sales_order.customer.try(:address)
            }
          }
        }

        if detailed
          data[:lines]   = stop.sales_order.lines.includes(:product).map do |l|
            {
              id:            l.id,
              product_id:    l.product_id,
              product_name:  l.product.name,
              ordered_qty:   l.qty,
              delivered_qty: l.delivered_qty,
              returned_qty:  l.returned_qty,
              unit_price:    l.unit_price
            }
          end
          data[:proof]   = stop.proof ? {
            proof_type:      stop.proof.proof_type,
            otp_verified_at: stop.proof.otp_verified_at,
            override_reason: stop.proof.override_reason,
            photo_url:       safe_attachment_url(stop.proof.photo),
            signature_url:   safe_attachment_url(stop.proof.signature_image)
          } : nil
          data[:returns] = stop.returns.includes(:product).map do |r|
            {
              id:           r.id,
              product_id:   r.product_id,
              product_name: r.product.name,
              qty_returned: r.qty_returned,
              condition:    r.condition,
              reason_code:  r.reason_code,
              notes:        r.notes
            }
          end
        end

        data
      end
    end
  end
end
