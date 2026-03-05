module Api
  module V1
    class DeliveryExceptionsController < BaseController
      before_action :require_organization!

      # GET /api/v1/delivery_exceptions
      # Returns all trip stops that have an exception_code.
      def index
        authorize TripStop.new, :index?

        base = policy_scope(TripStop)
                .joins(:delivery_trip)
                .where(delivery_trips: { organization: current_organization })
                .with_exception
                .includes(:delivery_trip, sales_order: [:customer])

        base = base.by_status(params[:status])                  if params[:status].present?
        base = base.where(exception_code: params[:exception_code]) if params[:exception_code].present?
        base = filter_by_date_range(base)

        stops   = paginate(base.order(created_at: :desc))
        summary = build_summary

        render_success(
          stops.map { |s| serialize_exception(s) },
          meta: pagination_meta(stops).merge(summary: summary)
        )
      end

      private

      def filter_by_date_range(scope)
        scope = scope.where('trip_stops.created_at >= ?', params[:from_date].to_date.beginning_of_day) if params[:from_date].present?
        scope = scope.where('trip_stops.created_at <= ?', params[:to_date].to_date.end_of_day)         if params[:to_date].present?
        scope
      rescue ArgumentError
        scope
      end

      def build_summary
        base = policy_scope(TripStop)
               .joins(:delivery_trip)
               .where(delivery_trips: { organization: current_organization })
               .with_exception

        {
          total_exceptions: base.count,
          by_code:          base.group(:exception_code).count,
          failed_stops:     base.by_status('failed').count
        }
      end

      def serialize_exception(stop)
        {
          id:             stop.id,
          sequence:       stop.sequence,
          status:         stop.status,
          exception_code: stop.exception_code,
          delivery_notes: stop.delivery_notes,
          delivered_at:   stop.delivered_at,
          trip: {
            id:          stop.delivery_trip.id,
            trip_number: stop.delivery_trip.trip_number,
            trip_date:   stop.delivery_trip.trip_date,
            status:      stop.delivery_trip.status
          },
          order: {
            id:           stop.sales_order.id,
            order_number: stop.sales_order.order_number,
            customer_name: stop.sales_order.customer.name,
            total_amount:  stop.sales_order.total_amount
          }
        }
      end
    end
  end
end
