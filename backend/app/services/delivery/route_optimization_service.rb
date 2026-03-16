# frozen_string_literal: true

module Delivery
  # Optimizes delivery trip stop sequence using OSRM (Open Source Routing Machine).
  # 
  # Usage:
  #   result = Delivery::RouteOptimizationService.call(
  #     delivery_trip: trip,
  #     actor: current_user
  #   )
  #
  #   result.success?           # => true/false
  #   result.optimized_stops    # => [TripStop, TripStop, ...]
  #   result.distance_saved_km  # => 2.5
  #   result.time_saved_min     # => 8
  class RouteOptimizationService
    Result = Struct.new(:success, :optimized_stops, :original_distance, :optimized_distance,
                        :distance_saved_km, :time_saved_min, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(delivery_trip:, actor: nil)
      @trip = delivery_trip
      @actor = actor
      @errors = []
    end

    def call
      validate!
      return failure if errors_present?

      optimize_route
      update_stops
      success_response
    rescue StandardError => error
      log_error("Route optimization failed", error)
      failure("#{error.class}: #{error.message}")
    end

    private

    attr_reader :trip, :actor, :errors

    def validate!
      @errors = []
      @errors << 'OSRM service not enabled' unless OSRM_CONFIG[:enabled]
      @errors << 'Delivery trip not found' unless @trip.present?
      @errors << 'Delivery trip has no stops' if @trip.stops.empty?
      @errors << 'Delivery trip has too many stops (max 100)' if @trip.stops.size > 100
      @errors << 'OSRM service not reachable' unless OSRMValidator.reachable?

      # Validate that all stops have coordinates
      missing_coords = @trip.stops.select { |s| s.latitude.blank? || s.longitude.blank? }
      if missing_coords.any?
        @errors << "#{missing_coords.count} stops are missing latitude/longitude coordinates"
      end
    end

    def errors_present?
      @errors.any?
    end

    def optimize_route
      osrm = OSRMClient.new

      # Extract coordinates (must be [lon, lat] for OSRM)
      @original_stops = @trip.stops.order(:sequence).to_a
      coordinates = @original_stops.map { |s| [s.longitude, s.latitude] }

      # Get optimized sequence from OSRM
      osrm_result = osrm.trip(coordinates)

      # Extract optimized waypoint order
      waypoints = osrm_result[:waypoints]
      optimized_indices = waypoints.map { |wp| wp['waypoint_index'] }

      # Reorder stops according to OSRM result
      @optimized_stops = optimized_indices.each_with_index.map do |original_idx, new_idx|
        @original_stops[original_idx]
      end

      # Calculate distance metrics
      calculate_distance_savings(osrm, coordinates, optimized_indices)
    rescue StandardError => error
      raise StandardError, "OSRM optimization error: #{error.message}"
    end

    def calculate_distance_savings(osrm, coordinates, optimized_indices)
      # Calculate original route distance
      @original_distance = 0
      @original_stops.each_with_index do |stop, idx|
        next if idx >= @original_stops.size - 1
        from_coord = [stop.longitude, stop.latitude]
        to_coord = [@original_stops[idx + 1].longitude, @original_stops[idx + 1].latitude]
        
        route_info = osrm.route(from_coord[1], from_coord[0], to_coord[1], to_coord[0])
        @original_distance += route_info[:distance]
      end

      # Calculate optimized route distance
      @optimized_distance = 0
      optimized_indices.each_with_index do |orig_idx, idx|
        next if idx >= optimized_indices.size - 1
        next_orig_idx = optimized_indices[idx + 1]
        
        from_coord = [@original_stops[orig_idx].longitude, @original_stops[orig_idx].latitude]
        to_coord = [@original_stops[next_orig_idx].longitude, @original_stops[next_orig_idx].latitude]
        
        route_info = osrm.route(from_coord[1], from_coord[0], to_coord[1], to_coord[0])
        @optimized_distance += route_info[:distance]
      end

      @distance_saved_m = @original_distance - @optimized_distance
      @distance_saved_km = (@distance_saved_m / 1000).round(2)
    rescue StandardError => error
      # If distance calculation fails, don't fail the optimization
      Rails.logger.warn("Could not calculate distance savings: #{error.message}")
      @distance_saved_km = 0
    end

    def update_stops
      ActiveRecord::Base.transaction do
        @optimized_stops.each_with_index do |stop, new_seq|
          stop.update!(sequence: new_seq)
        end

        # Record optimization in audit log
        if @actor.present?
          @trip.audit_logs.create!(
            action: 'route_optimized',
            actor: @actor,
            changes_data: {
              original_distance_m: @original_distance.to_i,
              optimized_distance_m: @optimized_distance.to_i,
              distance_saved_km: @distance_saved_km,
              stops_count: @trip.stops.count
            },
            reason: 'Automated OSRM route optimization'
          )
        end
      end
    end

    def success_response
      Result.new(
        success: true,
        optimized_stops: @optimized_stops,
        original_distance: @original_distance,
        optimized_distance: @optimized_distance,
        distance_saved_km: @distance_saved_km,
        time_saved_min: ((@original_distance - @optimized_distance) / 100).round(0), # rough estimate
        errors: []
      )
    end

    def failure(message = nil)
      Result.new(
        success: false,
        optimized_stops: [],
        original_distance: 0,
        optimized_distance: 0,
        distance_saved_km: 0,
        time_saved_min: 0,
        errors: @errors + [message].compact
      )
    end

    def log_error(message, error)
      Rails.logger.error({
        service: 'Delivery::RouteOptimizationService',
        message: message,
        trip_id: @trip&.id,
        error: error.message,
        backtrace: error.backtrace[0..4]
      }.to_json)
    end
  end
end
