module Delivery
  # Called automatically when an order is approved.
  # Adds the order to an existing open (draft/planned) trip on the same branch
  # and target date, or creates a new draft trip if none exists.
  #
  # Route-aware assignment:
  #   - Derives the route from order.customer.route.
  #   - When a route exists, it searches for an open trip tagged with that route
  #     first, then falls back to any open branch+date trip (so route-less trips
  #     created manually are re-used rather than creating duplicates).
  #   - Vehicle:  route.vehicle (if set)
  #   - Driver:   route.default_driver → route.vehicle.default_driver → nil
  #   - When no route is found the existing branch-wide trip match is used and
  #     no vehicle/driver is assigned (operator can fill in manually).
  #
  # Batch processing (all approved orders without trips):
  #   Delivery::AddOrderToTripService.call_batch_for_approved(
  #     actor:        current_user,
  #     organization: org,
  #     branch:       branch   # nil = all branches
  #   )
  #   # => { ok:, results: [{ order_number:, action:, trip_number: }], errors: [] }
  #
  # Single-order usage (called from ApproveOrderService):
  #   result = Delivery::AddOrderToTripService.call(actor:, order:)
  #   result[:action]    # => :added_to_existing | :new_trip_created | :already_on_trip
  #   result[:trip]      # => DeliveryTrip
  #   result[:stop]      # => TripStop
  #   result[:ok]        # => true / false
  #
  class AddOrderToTripService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    # Processes every approved order (with no trip stop) for the organisation.
    # Groups by route → branch → trip date so that each route gets its own trip
    # and route-specific vehicle/driver are assigned once.
    def self.call_batch_for_approved(actor:, organization:, branch: nil)
      scope = SalesOrder
                .where(organization: organization, status: 'approved')
                .left_outer_joins(:trip_stop)
                .where(trip_stops: { id: nil })
                .includes(customer: :route)

      scope = scope.where(branch: branch) if branch

      results = []
      errors  = []

      scope.find_each do |order|
        res = new(actor: actor, order: order).call
        entry = {
          order_number: order.order_number,
          action:       res[:action],
          trip_number:  res[:trip]&.trip_number,
          ok:           res[:ok]
        }
        results << entry
        errors.concat(res[:errors]) unless res[:ok]
      end

      { ok: errors.empty?, results: results, errors: errors }
    end

    def initialize(actor:, order:)
      @actor = actor
      @order = order
    end

    def call
      return { ok: false, errors: ['Order is not approved'] } unless @order.approved?

      # Skip if the order is already on a trip
      if @order.trip_stop.present?
        return { ok: true, trip: @order.trip_stop.delivery_trip,
                 stop: @order.trip_stop, action: :already_on_trip, errors: [] }
      end

      @route     = @order.customer&.route
      @trip_date = @order.delivery_date || Date.current
      existing   = open_trip_for(@trip_date)

      if existing
        stop = add_stop_to(existing)
        { ok: true, trip: existing, stop: stop, action: :added_to_existing, errors: [] }
      else
        create_new_trip(@trip_date)
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, trip: nil, stop: nil, errors: [e.message] }
    end

    private

    # Look for an open (draft/planned) trip for this order's branch + date.
    # When the customer has a route, prefer a trip already tagged with that route.
    # Falls back to any open branch+date trip (covers manual trips & routeless orders).
    def open_trip_for(trip_date)
      base = DeliveryTrip
               .where(organization: @order.organization,
                      branch:       @order.branch,
                      trip_date:    trip_date)
               .where(status: %w[draft planned])
               .order(:created_at)

      # Route-scoped match first
      if @route
        route_trip = base.find_by(route: @route)
        return route_trip if route_trip
      end

      # Fall back to any open trip on this branch+date (routeless or manual)
      base.first
    end

    def add_stop_to(trip)
      next_seq = (trip.stops.maximum(:sequence) || 0) + 1
      stop = TripStop.create!(
        delivery_trip: trip,
        sales_order:   @order,
        sequence:      next_seq,
        status:        'pending'
      )
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @order.organization,
        auditable:    trip,
        action:       'order_added_to_trip',
        changes:      { order_number: @order.order_number, sequence: next_seq,
                        route_code:   @route&.code }
      )
      stop
    end

    def create_new_trip(trip_date)
      vehicle = @route&.vehicle
      driver  = @route&.default_driver || vehicle&.default_driver

      notes_parts = ["Auto-created on approval of #{@order.order_number}"]
      notes_parts << "Route: #{@route.code} – #{@route.name}" if @route

      result = Delivery::TripCreateService.call(
        actor:        @actor,
        organization: @order.organization,
        branch:       @order.branch,
        trip_date:    trip_date,
        order_ids:    [@order.id],
        route:        @route,
        vehicle:      vehicle,
        driver:       driver,
        notes:        notes_parts.join(' | ')
      )

      if result[:ok]
        { ok: true, trip: result[:trip],
          stop: result[:trip].stops.first,
          action: :new_trip_created, errors: [] }
      else
        { ok: false, trip: nil, stop: nil, errors: result[:errors] }
      end
    end
  end
end
