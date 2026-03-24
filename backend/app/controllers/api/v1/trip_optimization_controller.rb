# ── Trip Optimization & Geocoding API Controller ──────────────────────────────────
# Endpoints for optimizing delivery routes, calculating distances & ETAs

module Api
  module V1
    class TripOptimizationController < BaseController
      before_action :require_organization!

      # ── Optimize Delivery Trip Stops ────────────────────────────────────────────
      # Reorders delivery stops for optimal route (shortest distance/time)
      #
      # POST /api/v1/trips/:trip_id/optimize
      #
      # Body:
      # {
      #   "origin": { "lat": 12.9716, "lng": 77.5946 },
      #   "stops": [
      #     { "id": 1, "lat": 12.9352, "lng": 77.6245, "address": "..." },
      #     { "id": 2, "lat": 12.9111, "lng": 77.6412, "address": "..." }
      #   ]
      # }
      #
      # @return [200] { optimized_stops: Array, total_distance_km: Float, total_duration_minutes: Int }
      def optimize_trip
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        origin = params.require(:origin).permit(:lat, :lng)
        stops_param = params.require(:stops)

        stops = stops_param.map do |stop|
          {
            id: stop[:id],
            lat: stop[:lat].to_f,
            lng: stop[:lng].to_f,
            address: stop[:address]
          }
        end

        begin
          maps = MapsService.new
          optimized = maps.optimize_route(origin, stops)

          render_success({
            optimized_stops: optimized,
            total_distance_km: 0,  # Would calculate from route
            total_duration_minutes: 0
          })
        rescue MapsService::RoutingError => e
          render_errors(["Route optimization failed: #{e.message}"], status: :service_unavailable)
        rescue MapsService::MapsConfigError => e
          render_errors(["Maps configuration error: #{e.message}"], status: :unprocessable_entity)
        end
      end

      # ── Calculate Distances Between Locations ───────────────────────────────────
      # Gets distance matrix between multiple origins and destinations
      #
      # POST /api/v1/trips/:trip_id/distances
      #
      # Body:
      # {
      #   "origins": [
      #     { "lat": 12.9716, "lng": 77.5946 },
      #     { "lat": 12.9352, "lng": 77.6245 }
      #   ],
      #   "destinations": [
      #     { "lat": 12.9111, "lng": 77.6412 },
      #     { "lat": 12.8761, "lng": 77.5955 }
      #   ],
      #   "mode": "driving"
      # }
      #
      # @return [200] { distances: Array<Array>, durations: Array<Array> }
      def calculate_distances
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        origins = params.require(:origins).map { |o| { lat: o[:lat].to_f, lng: o[:lng].to_f } }
        destinations = params.require(:destinations).map { |d| { lat: d[:lat].to_f, lng: d[:lng].to_f } }
        mode = params[:mode] || 'driving'

        begin
          maps = MapsService.new
          matrix = maps.distance_matrix(origins, destinations, mode)

          render_success({ distances: matrix })
        rescue MapsService::RoutingError => e
          render_errors(["Distance calculation failed: #{e.message}"], status: :service_unavailable)
        end
      end

      # ── Get Route Directions ────────────────────────────────────────────────────
      # Gets turn-by-turn directions between two points
      #
      # GET /api/v1/trips/:trip_id/directions?origin_lat=12.97&origin_lng=77.59&dest_lat=12.93&dest_lng=77.62
      #
      # @return [200] { polyline: String, distance_m: Int, duration_s: Int, steps: Array }
      def get_directions
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        origin_lat = params.require(:origin_lat)
        origin_lng = params.require(:origin_lng)
        dest_lat = params.require(:dest_lat)
        dest_lng = params.require(:dest_lng)

        origin = { lat: origin_lat.to_f, lng: origin_lng.to_f }
        destination = { lat: dest_lat.to_f, lng: dest_lng.to_f }

        begin
          maps = MapsService.new
          route = maps.directions(origin, destination)

          render_success(route)
        rescue MapsService::RoutingError => e
          render_errors(["Direction lookup failed: #{e.message}"], status: :service_unavailable)
        end
      end

      # ── Calculate ETA to Destination ────────────────────────────────────────────
      # Estimates arrival time from current location to destination
      #
      # POST /api/v1/trips/:trip_id/eta
      #
      # Body:
      # {
      #   "current_location": { "lat": 12.9716, "lng": 77.5946 },
      #   "destination": { "lat": 12.9352, "lng": 77.6245 }
      # }
      #
      # @return [200] { duration_minutes: Int, distance_meters: Int }
      def calculate_eta
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        current_location = params.require(:current_location).permit(:lat, :lng)
        destination = params.require(:destination).permit(:lat, :lng)

        begin
          maps = MapsService.new
          eta_data = maps.calculate_eta(current_location, destination)

          render_success(eta_data)
        rescue MapsService::RoutingError => e
          render_errors(["ETA calculation failed: #{e.message}"], status: :service_unavailable)
        end
      end

      # ── Geocode Address ─────────────────────────────────────────────────────────
      # Converts address to coordinates for new delivery stops
      #
      # POST /api/v1/trips/:trip_id/geocode
      #
      # Body:
      # {
      #   "address": "123 Main Street, Bangalore, Karnataka"
      # }
      #
      # @return [200] { lat: Float, lng: Float, formatted_address: String }
      def geocode_address
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        address = params.require(:address)

        begin
          maps = MapsService.new
          result = maps.geocode_address(address)

          render_success(result)
        rescue MapsService::GeocodingError => e
          render_errors(["Geocoding failed: #{e.message}"], status: :unprocessable_entity)
        end
      end

      # ── Reverse Geocode (Coordinates to Address) ────────────────────────────────
      # Converts coordinates to address
      #
      # GET /api/v1/trips/:trip_id/reverse_geocode?lat=12.97&lng=77.59
      #
      # @return [200] { address: String, city: String, state: String, zip: String }
      def reverse_geocode
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        lat = params.require(:lat).to_f
        lng = params.require(:lng).to_f

        begin
          maps = MapsService.new
          result = maps.reverse_geocode(lat, lng)

          render_success(result)
        rescue MapsService::GeocodingError => e
          render_errors(["Reverse geocoding failed: #{e.message}"], status: :unprocessable_entity)
        end
      end

      # ── Validate Address ────────────────────────────────────────────────────────
      # Validates address format and standardization
      #
      # POST /api/v1/trips/:trip_id/validate_address
      #
      # Body:
      # {
      #   "address": "123 Main St, Bangalore, KA"
      # }
      #
      # @return [200] { valid: Boolean, formatted_address: String, components: Hash }
      def validate_address
        trip = DeliveryTrip.for_org(current_organization.id).find(params[:trip_id])
        address = params.require(:address)

        begin
          maps = MapsService.new
          result = maps.validate_address(address)

          render_success(result)
        rescue MapsService::GeocodingError => e
          render_errors(["Address validation failed: #{e.message}"], status: :unprocessable_entity)
        end
      end
    end
  end
end
