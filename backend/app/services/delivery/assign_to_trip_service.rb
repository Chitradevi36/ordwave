# frozen_string_literal: true

module Delivery
  # Executes trip assignment for a sales order
  # Adds order to existing trip or creates a new trip
  #
  # Usage:
  #   result = Delivery::AssignToTripService.call(
  #     order: sales_order,
  #     trip_id: '123',  # or nil to create new
  #     driver_id: driver.id, # Required if creating new trip
  #     user: current_user
  #   )
  #   result.success? #=> true/false
  #   result.trip_stop #=> created TripStop
  #
  class AssignToTripService
    Result = Struct.new(:success?, :trip_stop, :trip, :message, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(order:, trip_id: nil, driver_id: nil, user:, trip_date: Date.today)
      @order = order
      @trip_id = trip_id
      @driver_id = driver_id
      @user = user
      @trip_date = trip_date
    end

    def call
      # Validate order can be assigned
      return failure("Order status must be 'approved'") unless @order.approved?
      return failure("Order already assigned to a trip") if @order.trip_stop.present?

      if @trip_id.present?
        assign_to_existing_trip
      elsif @driver_id.present?
        create_new_trip_and_assign
      else
        failure("Either trip_id or driver_id must be provided")
      end
    rescue StandardError => error
      Rails.logger.error("[AssignToTripService] Error: #{error.message}")
      failure("Assignment failed: #{error.message}")
    end

    private

    def assign_to_existing_trip
      trip = @order.organization.delivery_trips.find_by(id: @trip_id)
      return failure("Trip not found") unless trip.present?
      return failure("Trip not in draft/planned status") unless %w[draft planned].include?(trip.status)
      return failure("Trip is for different branch") if trip.branch_id != @order.branch_id
      return failure("Trip is for different date") if trip.trip_date != @trip_date

      ActiveRecord::Base.transaction do
        # Create trip stop
        trip_stop = TripStop.create!(
          delivery_trip: trip,
          sales_order: @order,
          sequence: trip.stops.count + 1,
          status: 'pending'
        )

        # Update order status
        @order.update!(status: 'dispatched')

        # Log audit trail
        Credit::AuditLogger.log(
          organization_id: @order.organization_id,
          user_id: @user.id,
          action: 'order_assigned_to_trip',
          resource_type: 'SalesOrder',
          resource_id: @order.id,
          changes: {
            status: ['approved', 'dispatched'],
            trip_id: [nil, trip.id]
          },
          metadata: {
            trip_number: trip.trip_number,
            assignment_type: 'auto_existing_trip'
          }
        )

        # Trigger route optimization if enabled
        if FEATURES.route_optimization_enabled?(@order.organization)
          RouteOptimizationJob.perform_later(trip.id, @user.id)
        end

        success(trip_stop: trip_stop, trip: trip, message: "Order assigned to trip #{trip.trip_number}")
      end
    end

    def create_new_trip_and_assign
      driver = @order.organization.users.find_by(id: @driver_id)
      return failure("Driver not found") unless driver.present?

      ActiveRecord::Base.transaction do
        # Create new trip
        trip = DeliveryTrip.create!(
          organization: @order.organization,
          branch: @order.branch,
          trip_date: @trip_date,
          driver: driver,
          status: 'planned',
          vehicle_id: find_vehicle_for_driver(driver)&.id
        )

        # Create trip stop
        trip_stop = TripStop.create!(
          delivery_trip: trip,
          sales_order: @order,
          sequence: 1,
          status: 'pending'
        )

        # Update order status
        @order.update!(status: 'dispatched')

        # Log audit trail
        Credit::AuditLogger.log(
          organization_id: @order.organization_id,
          user_id: @user.id,
          action: 'order_assigned_to_trip',
          resource_type: 'SalesOrder',
          resource_id: @order.id,
          changes: {
            status: ['approved', 'dispatched'],
            trip_id: [nil, trip.id]
          },
          metadata: {
            trip_number: trip.trip_number,
            assignment_type: 'auto_new_trip',
            driver_id: driver.id,
            driver_name: driver.name
          }
        )

        # Trigger route optimization
        if FEATURES.route_optimization_enabled?(@order.organization)
          RouteOptimizationJob.perform_later(trip.id, @user.id)
        end

        success(trip_stop: trip_stop, trip: trip, message: "New trip #{trip.trip_number} created for #{driver.name}")
      end
    end

    def find_vehicle_for_driver(driver)
      # Find vehicle assigned to driver, or first available vehicle
      driver.vehicle || @order.branch.vehicles.active.first
    end

    def success(trip_stop:, trip:, message:)
      Result.new(
        success?: true,
        trip_stop: trip_stop,
        trip: trip,
        message: message,
        errors: []
      )
    end

    def failure(error_msg)
      Result.new(
        success?: false,
        trip_stop: nil,
        trip: nil,
        message: nil,
        errors: [error_msg]
      )
    end
  end
end
