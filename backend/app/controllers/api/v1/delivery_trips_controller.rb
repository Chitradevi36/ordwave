module Api
  module V1
    class DeliveryTripsController < BaseController
      before_action :require_organization!
      before_action :set_trip, only: %i[show update dispatch_trip cancel summary optimize]

      TRIP_INCLUDES = [
        :vehicle, :driver, :branch,
        { stops: { sales_order: :customer } }
      ].freeze

      # POST /api/v1/delivery_trips/auto_create
      def auto_create
        authorize DeliveryTrip.new(organization: current_organization), :create?

        branch    = params[:branch_id].present? ?
                    current_organization.branches.find_by(id: params[:branch_id]) : nil
        trip_date = params[:trip_date].presence || Date.today.to_s

        result = Delivery::TripAutoCreateService.call(
          actor:        current_user,
          organization: current_organization,
          trip_date:    trip_date,
          branch:       branch
        )

        if result[:ok]
          render_success(
            result[:trips].map { |t| serialize_trip(t) },
            meta: {
              trips_created:    result[:trips].size,
              skipped_branches: result[:skipped_branches]
            }
          )
        else
          render_errors(result[:errors])
        end
      end

      # GET /api/v1/delivery_trips
      def index
        base   = policy_scope(DeliveryTrip).includes(:vehicle, :driver, :stops, :branch)
        base   = base.by_status(params[:status])         if params[:status].present?
        base   = base.by_branch(params[:branch_id])      if params[:branch_id].present?
        base   = base.by_driver(params[:driver_id])      if params[:driver_id].present?
        base   = base.by_date_range(params[:from_date], params[:to_date])
        base   = base.where('trip_number ILIKE ?', "%#{params[:q].strip}%") if params[:q].present?

        counts = policy_scope(DeliveryTrip).group(:status).count

        trips  = paginate(base.includes(*TRIP_INCLUDES).recent)
        render_success(
          trips.map { |t| serialize_trip(t) },
          meta: pagination_meta(trips).merge(counts: counts)
        )
      end

      # GET /api/v1/delivery_trips/:id
      def show
        authorize @trip
        render_success(serialize_trip(@trip, detailed: true))
      end

      # POST /api/v1/delivery_trips
      def create
        authorize DeliveryTrip.new(organization: current_organization), :create?

        branch = current_organization.branches.find(trip_params[:branch_id])
        vehicle = trip_params[:vehicle_id].present? ?
                  Vehicle.not_deleted.find_by(id: trip_params[:vehicle_id], organization: current_organization) : nil
        driver  = trip_params[:driver_id].present? ?
                  User.active.find_by(id: trip_params[:driver_id]) : nil

        result = Delivery::TripCreateService.call(
          actor:        current_user,
          organization: current_organization,
          branch:       branch,
          trip_date:    trip_params[:trip_date],
          vehicle:      vehicle,
          driver:       driver,
          order_ids:    trip_params[:order_ids],
          notes:        trip_params[:notes]
        )

        if result[:ok]
          render_created(serialize_trip(result[:trip], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # PATCH /api/v1/delivery_trips/:id
      def update
        authorize @trip

        vehicle = trip_params[:vehicle_id] == '' ? nil :
                  (trip_params[:vehicle_id].present? ?
                   Vehicle.not_deleted.find_by(id: trip_params[:vehicle_id], organization: current_organization) :
                   :skip)
        driver  = trip_params[:driver_id] == '' ? nil :
                  (trip_params[:driver_id].present? ?
                   User.active.find_by(id: trip_params[:driver_id]) :
                   :skip)

        result = Delivery::TripEditService.call(
          actor:      current_user,
          trip:       @trip,
          trip_date:  trip_params[:trip_date],
          vehicle:    vehicle,
          driver:     driver,
          notes:      trip_params.key?(:notes) ? trip_params[:notes] : :skip,
          order_ids:  trip_params[:order_ids]
        )

        if result[:ok]
          render_success(serialize_trip(result[:trip], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/delivery_trips/:id/dispatch
      def dispatch_trip
        authorize @trip, :dispatch?

        result = Delivery::TripDispatchService.call(actor: current_user, trip: @trip)
        if result[:ok]
          render_success(serialize_trip(result[:trip]))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/delivery_trips/:id/optimize
      def optimize
        authorize @trip, :optimize?

        result = Delivery::RouteOptimizationService.call(
          delivery_trip: @trip,
          actor: current_user
        )

        if result.success?
          render_success({
            trip: serialize_trip(@trip.reload),
            optimization_metrics: {
              original_distance_km: (result.original_distance / 1000).round(2),
              optimized_distance_km: (result.optimized_distance / 1000).round(2),
              distance_saved_km: result.distance_saved_km,
              time_saved_min: result.time_saved_min,
              stops_count: @trip.stops.count
            }
          })
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/delivery_trips/:id/cancel
      def cancel
        authorize @trip, :cancel?

        result = Delivery::CancelTripService.call(
          actor:  current_user,
          trip:   @trip,
          reason: params.dig(:delivery_trip, :cancellation_reason).presence ||
                  params[:reason].to_s
        )

        if result[:ok]
          render_success(serialize_trip(result[:trip]))
        else
          render_errors(result[:errors])
        end
      end

      # GET /api/v1/delivery_trips/:id/summary
      def summary
        authorize @trip, :show?

        stops  = @trip.stops.includes({ sales_order: %i[lines customer] }, :returns)
        total_stops    = stops.size
        delivered      = stops.count { |s| s.status == 'delivered' }
        partial        = stops.count { |s| s.status == 'partial_delivery' }
        failed         = stops.count { |s| s.status == 'failed' }
        skipped        = stops.count { |s| s.status == 'skipped' }

        total_order_value = stops.sum { |s| s.sales_order.total_amount.to_f }

        delivered_value = stops
          .select { |s| s.status.in?(%w[delivered partial_delivery]) }
          .sum do |s|
            s.sales_order.lines.sum { |l| (l.delivered_qty.to_i * l.unit_price.to_f) }
          end

        returns_value = stops.sum do |s|
          s.returns.sum do |r|
            order_line = s.sales_order.lines.find { |l| l.product_id == r.product_id }
            r.qty_returned.to_i * order_line&.unit_price.to_f
          end
        end

        # Cash collected: payments linked via invoices on this trip's orders
        # (payments have no direct sales_order_id; path is order → invoice → payment_allocation → payment)
        trip_order_ids  = stops.map(&:sales_order_id).compact
        trip_invoice_ids = SalesInvoice.where(sales_order_id: trip_order_ids).pluck(:id)
        cash_collected = if trip_invoice_ids.any?
          PaymentAllocation
            .joins(:payment)
            .where(sales_invoice_id: trip_invoice_ids)
            .where(payments: { payment_mode: 'cash' })
            .sum(:amount_applied)
        else
          0
        end

        exceptions = stops
          .select { |s| s.exception_code.present? }
          .map { |s| { stop_id: s.id, customer_name: s.sales_order.customer.name, exception_code: s.exception_code } }

        render_success({
          trip_id:           @trip.id,
          trip_number:       @trip.trip_number,
          total_stops:       total_stops,
          delivered:         delivered,
          partial:           partial,
          failed:            failed,
          skipped:           skipped,
          total_order_value: total_order_value.round(2),
          delivered_value:   delivered_value.round(2),
          returns_value:     returns_value.round(2),
          cash_collected:    cash_collected.to_f.round(2),
          exceptions:        exceptions
        })
      end

      private

      def set_trip
        @trip = policy_scope(DeliveryTrip).includes(*TRIP_INCLUDES).find(params[:id])
      end

      def trip_params
        params.require(:delivery_trip).permit(
          :branch_id, :vehicle_id, :driver_id, :trip_date, :notes,
          order_ids: []
        )
      end

      def serialize_trip(trip, detailed: false)
        data = {
          id:                   trip.id,
          trip_number:          trip.trip_number,
          trip_date:            trip.trip_date,
          status:               trip.status,
          branch:               { id: trip.branch_id, name: trip.branch.name },
          vehicle:              trip.vehicle ? { id: trip.vehicle.id, registration_number: trip.vehicle.registration_number, vehicle_type: trip.vehicle.vehicle_type } : nil,
          driver:               trip.driver  ? { id: trip.driver.id,  name: trip.driver.full_name } : nil,
          stops_count:          trip.stops.size,
          stops_completed_count: trip.stops.count(&:completed?),
          notes:                trip.notes,
          cancellation_reason:  trip.cancellation_reason,
          dispatched_at:        trip.dispatched_at,
          completed_at:         trip.completed_at,
          created_at:           trip.created_at
        }

        if detailed
          data[:stops] = trip.stops.ordered.map { |s| serialize_stop(s) }
        end

        data
      end

      def serialize_stop(stop)
        {
          id:             stop.id,
          sequence:       stop.sequence,
          status:         stop.status,
          exception_code: stop.exception_code,
          delivered_at:   stop.delivered_at,
          delivery_notes: stop.delivery_notes,
          sales_order: {
            id:           stop.sales_order.id,
            order_number: stop.sales_order.order_number,
            customer:     { id: stop.sales_order.customer_id, name: stop.sales_order.customer.name },
            total_amount: stop.sales_order.total_amount
          }
        }
      end
    end
  end
end
