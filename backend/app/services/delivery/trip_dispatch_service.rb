module Delivery
  # Transitions a delivery trip from draft/planned → dispatched.
  # Also marks all associated SalesOrders as 'dispatched'.
  #
  # Usage:
  #   result = Delivery::TripDispatchService.call(
  #     actor: current_user,
  #     trip:  delivery_trip
  #   )
  #
  class TripDispatchService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, trip:)
      @actor = actor
      @trip  = trip
    end

    def call
      errors = validate
      return { ok: false, trip: @trip, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @trip.transition_to!('dispatched')

        # Move all approved orders on this trip to dispatched
        @trip.stops.not_deleted.includes(:sales_order).each do |stop|
          order = stop.sales_order
          if order.approved?
            order.transition_to!('dispatched')
            Credit::AuditLogger.log(
              actor:        @actor,
              organization: @trip.organization,
              auditable:    order,
              action:       'order_dispatched',
              changes:      { status: 'dispatched', trip_number: @trip.trip_number }
            )
          end
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @trip.organization,
          auditable:    @trip,
          action:       'trip_dispatched',
          changes:      { status: 'dispatched', dispatched_at: @trip.dispatched_at }
        )

        { ok: true, trip: @trip.reload, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, trip: @trip, errors: [e.message] }
    end

    private

    def validate
      errs = []
      unless %w[draft planned].include?(@trip.status)
        errs << 'Trip must be in draft or planned status to dispatch'
      end
      errs << 'Trip must have at least one stop' unless @trip.stops.not_deleted.any?
      errs
    end
  end
end
