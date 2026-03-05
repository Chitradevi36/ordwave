module Delivery
  # Cancels a delivery trip and reverts all dispatched orders back to 'approved'.
  #
  # Usage:
  #   result = Delivery::CancelTripService.call(
  #     actor:  current_user,
  #     trip:   delivery_trip,
  #     reason: "Vehicle breakdown"
  #   )
  #
  class CancelTripService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, trip:, reason:)
      @actor  = actor
      @trip   = trip
      @reason = reason
    end

    def call
      errors = validate
      return { ok: false, trip: @trip, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @trip.update!(status: 'cancelled', cancellation_reason: @reason)

        # Revert dispatched orders to approved so they can be re-routed
        @trip.stops.includes(:sales_order).each do |stop|
          order = stop.sales_order
          if order.dispatched?
            order.update!(status: 'approved', dispatched_at: nil)
            Credit::AuditLogger.log(
              actor:        @actor,
              organization: @trip.organization,
              auditable:    order,
              action:       'order_approved',
              changes:      { status: 'approved', reverted_reason: 'trip_cancelled' }
            )
          end
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @trip.organization,
          auditable:    @trip,
          action:       'trip_cancelled',
          changes:      { status: 'cancelled' },
          reason:       @reason
        )

        { ok: true, trip: @trip.reload, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, trip: @trip, errors: [e.message] }
    end

    private

    def validate
      errs = []
      errs << 'Reason is required to cancel a trip' if @reason.blank?
      errs << 'Trip cannot be cancelled in its current state' unless @trip.cancellable?
      errs
    end
  end
end
