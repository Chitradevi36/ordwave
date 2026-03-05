module Delivery
  # Updates a trip's metadata (vehicle, driver, date, notes) and re-orders stops.
  # Only allowed while trip is draft or planned.
  #
  # Usage:
  #   result = Delivery::TripEditService.call(
  #     actor:       current_user,
  #     trip:        delivery_trip,
  #     trip_date:   Date.today,
  #     vehicle:     vehicle,
  #     driver:      user,
  #     notes:       "text",
  #     order_ids:   [3, 1, 2]   # new sequence; nil = don't change stops
  #   )
  #
  class TripEditService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, trip:, trip_date: nil, vehicle: :skip, driver: :skip,
                   notes: :skip, order_ids: nil)
      @actor     = actor
      @trip      = trip
      @trip_date = trip_date
      @vehicle   = vehicle
      @driver    = driver
      @notes     = notes
      @order_ids = order_ids
    end

    def call
      errors = validate
      return { ok: false, trip: @trip, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        attrs = {}
        attrs[:trip_date]  = @trip_date  if @trip_date.present?
        attrs[:vehicle]    = @vehicle    unless @vehicle == :skip
        attrs[:driver]     = @driver     unless @driver  == :skip
        attrs[:notes]      = @notes      unless @notes   == :skip
        @trip.update!(attrs) if attrs.any?

        if @order_ids
          reorder_stops!
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @trip.organization,
          auditable:    @trip,
          action:       'trip_planned',
          changes:      attrs.transform_values { |v| v.respond_to?(:id) ? v.id : v }
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
        errs << 'Trip can only be edited in draft or planned status'
      end

      if @order_ids
        org_id  = @trip.organization_id
        found   = SalesOrder.where(id: @order_ids, organization_id: org_id,
                                   status: %w[approved dispatched]).pluck(:id)
        missing = @order_ids.map(&:to_i) - found
        errs << "Orders not found or not approvable: #{missing.join(', ')}" if missing.any?
      end
      errs
    end

    def reorder_stops!
      existing_order_ids = @trip.stops.pluck(:sales_order_id)
      new_order_ids      = @order_ids.map(&:to_i)

      # Remove stops no longer in list
      removed = existing_order_ids - new_order_ids
      @trip.stops.where(sales_order_id: removed).each do |stop|
        order = stop.sales_order
        order.update!(status: 'approved') if order.dispatched?
        stop.destroy!
      end

      # Add new stops
      added = new_order_ids - existing_order_ids
      added.each do |oid|
        TripStop.create!(delivery_trip: @trip, sales_order_id: oid,
                         sequence: 0, status: 'pending')
      end

      # Re-sequence in given order
      new_order_ids.each_with_index do |oid, idx|
        @trip.stops.find_by(sales_order_id: oid)&.update!(sequence: idx + 1)
      end
    end
  end
end
