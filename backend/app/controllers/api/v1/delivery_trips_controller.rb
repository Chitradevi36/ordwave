module Api
  module V1
    class DeliveryTripsController < BaseController
      before_action :require_organization!
      before_action :set_trip, only: %i[show update dispatch_trip cancel]

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
