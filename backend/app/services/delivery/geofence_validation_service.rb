# frozen_string_literal: true

module Delivery
  # Validates that a delivery completion is within geofence radius of the customer location.
  # This helps prevent fraudulent or incorrectly marked deliveries.
  #
  # Usage:
  #   result = Delivery::GeofenceValidationService.call(
  #     trip_stop: stop,
  #     latitude: 12.9716,
  #     longitude: 77.5946,
  #     geofence_radius_m: 100  # optional, uses org default if not provided
  #   )
  #
  #   result.valid?              # => true/false
  #   result.distance_m          # => 45.2
  #   result.status              # => 'within_geofence' | 'outside_geofence' | 'distance_not_calculable'
  #   result.message             # => "Location verified" or error message
  class GeofenceValidationService
    Result = Struct.new(:valid, :distance_m, :status, :message, keyword_init: true) do
      def valid? = valid
    end

    # Default geofence radius: 100 meters
    DEFAULT_GEOFENCE_RADIUS_M = 100

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(trip_stop:, latitude:, longitude:, geofence_radius_m: nil)
      @stop = trip_stop
      @delivery_lat = latitude
      @delivery_lon = longitude
      @geofence_radius_m = geofence_radius_m || organization_geofence_radius || DEFAULT_GEOFENCE_RADIUS_M
    end

    def call
      validate_inputs
      calculate_distance
      determine_result
    end

    private

    def validate_inputs
      @errors = []
      @errors << 'Trip stop not found' unless @stop.present?
      @errors << 'Delivery latitude not provided' if @delivery_lat.blank?
      @errors << 'Delivery longitude not provided' if @delivery_lon.blank?

      return if @errors.empty?

      return failure('distance_not_calculable', 'Invalid input data', @errors.first)
    end

    def calculate_distance
      customer = @stop.sales_order&.customer
      return failure('distance_not_calculable', 'Customer not found') unless customer

      delivery_address = customer.primary_address
      return failure('distance_not_calculable', 'Customer address not found') unless delivery_address

      # Use Haversine formula to calculate distance between two GPS coordinates
      @distance_m = haversine_distance(
        delivery_address.latitude.to_f,
        delivery_address.longitude.to_f,
        @delivery_lat.to_f,
        @delivery_lon.to_f
      )
    rescue StandardError => error
      Rails.logger.error({
        service: 'Delivery::GeofenceValidationService',
        error: error.message,
        stop_id: @stop&.id
      }.to_json)
      return failure('distance_not_calculable', "Distance calculation failed: #{error.message}")
    end

    def determine_result
      if @distance_m <= @geofence_radius_m
        success('within_geofence', "Location verified (#{@distance_m.round(1)}m from address)")
      else
        failure(
          'outside_geofence',
          "Delivery location is #{@distance_m.round(1)}m from address (exceeds #{@geofence_radius_m}m limit)",
          "Distance: #{@distance_m.round(1)}m, Geofence: #{@geofence_radius_m}m"
        )
      end
    end

    def success(status, message)
      Result.new(
        valid: true,
        distance_m: @distance_m,
        status: status,
        message: message
      )
    end

    def failure(status, message, details = nil)
      Result.new(
        valid: false,
        distance_m: @distance_m || 0,
        status: status,
        message: message
      )
    end

    # Haversine formula distance calculation
    # Returns distance in meters between two GPS points
    def haversine_distance(lat1, lon1, lat2, lon2)
      R = 6_371_000  # Earth's radius in meters

      # Convert to radians
      lat1_rad = Math.atan2(Math.sin(lat1 * Math::PI / 180), Math.cos(lat1 * Math::PI / 180))
      lat2_rad = Math.atan2(Math.sin(lat2 * Math::PI / 180), Math.cos(lat2 * Math::PI / 180))
      
      delta_lat = (lat2 - lat1) * Math::PI / 180
      delta_lon = (lon2 - lon1) * Math::PI / 180

      # Haversine formula
      a = Math.sin(delta_lat / 2) ** 2 +
          Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(delta_lon / 2) ** 2)
      
      c = 2 * Math.asin(Math.sqrt(a))
      R * c
    end

    def organization_geofence_radius
      organization = @stop&.delivery_trip&.organization
      return nil unless organization

      # Try to get from org settings (adjust key as needed)
      organization.settings&.dig('delivery_geofence_radius_m')
    end
  end
end
