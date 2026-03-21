module Delivery
  # Creates a new delivery trip (in draft status) with an ordered list of stops.
  #
  # Usage:
  #   result = Delivery::TripCreateService.call(
  #     actor:           current_user,
  #     organization:    current_organization,
  #     branch:          branch,
  #     trip_date:       Date.today,
  #     vehicle:         vehicle,          # optional
  #     driver:          driver_user,      # optional
  #     order_ids:       [1, 2, 3],        # ordered list of approved SalesOrder ids
  #     notes:           "Morning route"   # optional
  #   )
  #
  class TripCreateService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, organization:, branch:, trip_date:, order_ids:,
                   vehicle: nil, driver: nil, route: nil, notes: nil)
      @actor        = actor
      @organization = organization
      @branch       = branch
      @trip_date    = trip_date
      @vehicle      = vehicle
      @driver       = driver
      @route        = route
      @order_ids    = Array(order_ids)
      @notes        = notes
    end

    def call
      errors = validate
      return { ok: false, trip: nil, errors: errors } if errors.any?

      trip = nil
      ActiveRecord::Base.transaction do
        trip = DeliveryTrip.create!(
          organization: @organization,
          branch:       @branch,
          route:        @route,
          vehicle:      @vehicle,
          driver:       @driver,
          trip_date:    @trip_date,
          notes:        @notes,
          status:       'draft'
        )

        orders.each_with_index do |order, idx|
          TripStop.create!(
            delivery_trip: trip,
            sales_order:   order,
            sequence:      idx + 1,
            status:        'pending'
          )
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @organization,
          auditable:    trip,
          action:       'trip_created',
          changes:      { trip_number: trip.trip_number, stop_count: @order_ids.size }
        )
      end

      # Enqueue route optimization job after transaction succeeds
      # Runs async if > 2 stops and auto-optimization enabled
      RouteOptimizationJob.perform_later(trip.id, @actor&.id)

      { ok: true, trip: trip.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, trip: nil, errors: [e.message] }
    end

    private

    def orders
      @orders ||= SalesOrder.where(
        id:              @order_ids,
        organization_id: @organization.id,
        status:          'approved'
      ).order(Arel.sql("ARRAY_POSITION(ARRAY[#{@order_ids.map(&:to_i).join(',')}]::bigint[], id)"))
    end

    def validate
      errs = []
      errs << 'Trip date is required' if @trip_date.blank?
      errs << 'At least one order is required' if @order_ids.empty?

      if @vehicle && @vehicle.organization_id != @organization.id
        errs << 'Vehicle does not belong to this organization'
      end

      if @driver && @driver.membership_for(@organization).blank?
        errs << 'Driver is not a member of this organization'
      end

      found_ids = orders.pluck(:id)
      missing   = @order_ids.map(&:to_i) - found_ids
      errs << "Orders not found or not approved: #{missing.join(', ')}" if missing.any?

      errs
    end
  end
end
