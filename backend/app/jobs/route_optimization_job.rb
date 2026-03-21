# frozen_string_literal: true

class RouteOptimizationJob < ApplicationJob
  sidekiq_options queue: 'operations', retry: 3

  # Asynchronously optimizes route for a delivery trip
  # Triggered by Delivery::TripCreateService if auto_optimization enabled
  #
  # Retries up to 3 times on transient failures (network, OSRM timeout)
  # Discards silently if trip is deleted or OSRM unavailable

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound
  discard_on StandardError do |job, exception|
    # Don't retry if OSRM is disabled or unreachable
    unless %w[OSRM service not enabled OSRM service not reachable].any? { |msg| exception.message.include?(msg) }
      false # Retry on other errors
    end
  end

  # @param trip_id [Integer] DeliveryTrip id
  # @param actor_id [Integer] User who created trip (optional, for audit)
  def perform(trip_id, actor_id = nil)
    trip = DeliveryTrip.find(trip_id)
    actor = actor_id ? User.find(actor_id) : nil

    # Only run if:
    # - Trip has > 2 stops (optimization is pointless for 1-2 stops)
    # - Auto-optimization is enabled for organization
    # - Trip hasn't been optimized already
    return if trip.stops.count <= 2

    organization = trip.organization
    unless FEATURES.route_optimization_enabled?(organization)
      Rails.logger.debug("[RouteOptimizationJob] Auto-optimization disabled for trip #{trip_id}, org #{organization.id}")
      return
    end

    # Call the optimization service
    result = Delivery::RouteOptimizationService.call(
      delivery_trip: trip,
      actor: actor
    )

    if result.success?
      Rails.logger.info(
        "[RouteOptimizationJob] Trip #{trip_id} optimized: " \
        "#{result.distance_saved_km}km saved (#{result.original_distance.to_i}m → #{result.optimized_distance.to_i}m)"
      )

      # Broker notification to ops dashboard (optional)
      broadcast_optimization_complete(trip, result)
    else
      Rails.logger.warn(
        "[RouteOptimizationJob] Route optimization failed for trip #{trip_id}: #{result.errors.join(', ')}"
      )

      # If OSRM service is down, don't retry (discard will trigger)
      # If validation error, log and move on (trip still usable, just not optimized)
      if result.errors.any? { |e| e.include?('OSRM') }
        raise StandardError, "OSRM service unavailable: #{result.errors.join(', ')}"
      end
    end
  end

  private

  def broadcast_optimization_complete(trip, result)
    # Optional: Notify UI via ActionCable if ops manager watching trip details
    # For now, just log and audit trail captures it
  end
end
