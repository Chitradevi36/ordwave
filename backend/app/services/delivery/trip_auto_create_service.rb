module Delivery
  # Automatically creates delivery trips for a given date by grouping all
  # approved orders per branch and assigning the first free vehicle + driver.
  #
  # Rules:
  #   - Skips a branch if a draft/planned trip already exists for that date.
  #   - Picks the first active vehicle not already assigned to another trip on
  #     that date.
  #   - Picks the first driver (role=driver membership) not already driving that day.
  #   - Vehicle and driver are optional — trip is created even without them.
  #
  # Usage:
  #   result = Delivery::TripAutoCreateService.call(
  #     actor:        current_user,
  #     organization: current_organization,
  #     trip_date:    Date.today,
  #     branch:       branch   # nil = all active branches
  #   )
  #   # => { ok: true, trips: [...], skipped_branches: ["Main Branch"], errors: [] }
  #
  class TripAutoCreateService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, organization:, trip_date:, branch: nil)
      @actor        = actor
      @organization = organization
      @trip_date    = trip_date.to_date
      @branch       = branch
    end

    def call
      created  = []
      skipped  = []
      errors   = []

      target_branches.each do |branch|
        orders = approved_orders_for(branch)

        if orders.empty?
          skipped << branch.name
          next
        end

        # Skip if a non-cancelled trip already exists for this branch + date
        if existing_trip?(branch)
          skipped << branch.name
          next
        end

        vehicle = available_vehicle
        driver  = available_driver

        result = Delivery::TripCreateService.call(
          actor:        @actor,
          organization: @organization,
          branch:       branch,
          trip_date:    @trip_date,
          vehicle:      vehicle,
          driver:       driver,
          order_ids:    orders.pluck(:id)
        )

        if result[:ok]
          created << result[:trip]
          # Mark vehicle/driver as "used" for subsequent branches in the same call
          @used_vehicle_ids = (@used_vehicle_ids || []) + [vehicle.id] if vehicle
          @used_driver_ids  = (@used_driver_ids  || []) + [driver.id]  if driver
        else
          errors.concat(result[:errors])
        end
      end

      {
        ok:               errors.empty?,
        trips:            created,
        skipped_branches: skipped,
        errors:           errors
      }
    end

    private

    def target_branches
      @branch ? [@branch] : @organization.branches.active.to_a
    end

    def approved_orders_for(branch)
      SalesOrder.where(
        organization: @organization,
        branch:       branch,
        status:       'approved'
      ).order(:created_at)
    end

    def existing_trip?(branch)
      DeliveryTrip.where(
        organization: @organization,
        branch:       branch,
        trip_date:    @trip_date
      ).where(status: %w[draft planned dispatched]).exists?
    end

    # First active vehicle not already on a trip today (including ones created in
    # this call via @used_vehicle_ids)
    def available_vehicle
      busy_ids = DeliveryTrip
                   .where(organization: @organization, trip_date: @trip_date)
                   .where.not(vehicle_id: nil)
                   .pluck(:vehicle_id)
      busy_ids |= (@used_vehicle_ids || [])

      Vehicle.active.where(organization: @organization).where.not(id: busy_ids).first
    end

    # First driver membership not already assigned to a trip today
    def available_driver
      busy_ids = DeliveryTrip
                   .where(organization: @organization, trip_date: @trip_date)
                   .where.not(driver_id: nil)
                   .pluck(:driver_id)
      busy_ids |= (@used_driver_ids || [])

      driver_role = Role.find_by(name: 'driver')
      return nil unless driver_role

      Membership.active
                .where(organization: @organization, role: driver_role)
                .where.not(user_id: busy_ids)
                .first
                &.user
    end
  end
end
