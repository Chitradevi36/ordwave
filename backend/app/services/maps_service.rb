require 'google/maps'

# ── Maps Service ───────────────────────────────────────────────────────────────
# Handles geolocation, route optimization, and distance calculations using Google Maps API
# Supports: address geocoding, distance matrix, route optimization, address validation

class MapsService
  # ── Errors ─────────────────────────────────────────────────────────────────────
  class MapsConfigError < StandardError; end
  class GeocodingError < StandardError; end
  class RoutingError < StandardError; end

  # ── Constants ──────────────────────────────────────────────────────────────────
  DEFAULT_DELIVERY_MODE = 'driving'
  DEPARTURE_TIME_BUFFER = 15.minutes # Buffer before trip start for API

  def initialize
    validate_config!
    @client = Google::Maps.new(key: ENV.fetch('GOOGLE_MAPS_API_KEY'))
  end

  # ── Address Geocoding ──────────────────────────────────────────────────────────
  # Converts address string to latitude/longitude coordinates
  #
  # @param address [String] Physical address (e.g., "123 Main St, Bangalore, 560001")
  # @return [Hash] { lat: Float, lng: Float, formatted_address: String }
  # @raise [GeocodingError] If address cannot be geocoded
  def geocode_address(address)
    begin
      result = @client.geocode(address: address).first

      if result.blank?
        raise GeocodingError, "Address not found: #{address}"
      end

      {
        latitude: result[:geometry][:location][:lat],
        longitude: result[:geometry][:location][:lng],
        formatted_address: result[:formatted_address],
        address_components: result[:address_components],
        place_id: result[:place_id]
      }
    rescue Google::Maps::Error => e
      raise GeocodingError, "Geocoding failed: #{e.message}"
    end
  end

  # ── Reverse Geocoding ──────────────────────────────────────────────────────────
  # Converts latitude/longitude to address
  #
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @return [Hash] { address: String, city: String, state: String, postal_code: String }
  # @raise [GeocodingError] If reverse geocoding fails
  def reverse_geocode(latitude, longitude)
    begin
      result = @client.geocode(latlng: { lat: latitude, lng: longitude }).first

      if result.blank?
        raise GeocodingError, "No address found for coordinates: #{latitude}, #{longitude}"
      end

      parse_address_components(result[:address_components])
    rescue Google::Maps::Error => e
      raise GeocodingError, "Reverse geocoding failed: #{e.message}"
    end
  end

  # ── Distance Matrix ────────────────────────────────────────────────────────────
  # Calculates distances and travel times between multiple locations
  #
  # @param origins [Array<Hash>] Starting points [{lat: Float, lng: Float}, ...]
  # @param destinations [Array<Hash>] Ending points [{lat: Float, lng: Float}, ...]
  # @param mode [String] Travel mode: 'driving' (default), 'walking', 'transit', 'bicycling'
  # @return [Array<Array<Hash>>] Distance matrix [[{distance_m: Int, duration_s: Int}, ...], ...]
  # @raise [RoutingError] If API call fails
  def distance_matrix(origins, destinations, mode = DEFAULT_DELIVERY_MODE)
    begin
      result = @client.distance_matrix(
        origins: origins.map { |o| [o[:lat], o[:lng]] },
        destinations: destinations.map { |d| [d[:lat], d[:lng]] },
        mode: mode
      )

      parse_distance_matrix(result)
    rescue Google::Maps::Error => e
      raise RoutingError, "Distance matrix failed: #{e.message}"
    end
  end

  # ── Directions (Route) ─────────────────────────────────────────────────────────
  # Gets detailed route between two points (directions, waypoints, polylines)
  #
  # @param origin [Hash] Starting point {lat: Float, lng: Float}
  # @param destination [Hash] Ending point {lat: Float, lng: Float}
  # @param waypoints [Array<Hash>] Intermediate stops [{lat: Float, lng: Float}, ...]
  # @param mode [String] Travel mode (default: 'driving')
  # @return [Hash] { distance_m: Int, duration_s: Int, polyline: String, steps: Array }
  # @raise [RoutingError] If route cannot be calculated
  def directions(origin, destination, waypoints = [], mode = DEFAULT_DELIVERY_MODE)
    begin
      waypoint_coords = waypoints.map { |w| [w[:lat], w[:lng]] }

      result = @client.directions(
        origin: [origin[:lat], origin[:lng]],
        destination: [destination[:lat], destination[:lng]],
        waypoints: waypoint_coords.any? ? waypoint_coords : nil,
        mode: mode,
        optimize_waypoints: true
      ).first

      if result.blank?
        raise RoutingError, "No route found between origin and destination"
      end

      parse_route(result)
    rescue Google::Maps::Error => e
      raise RoutingError, "Directions failed: #{e.message}"
    end
  end

  # ── Optimize Route ─────────────────────────────────────────────────────────────
  # Calculates optimal delivery order for multiple stops (TSP approximation)
  # Uses Google Directions API with waypoint optimization
  #
  # @param origin [Hash] Starting point {lat: Float, lng: Float}
  # @param stops [Array<Hash>] Delivery stops [{id: Int, lat: Float, lng: Float}, ...]
  # @return [Array<Hash>] Stops in optimized order [{id: Int, lat: Float, lng: Float, sequence: Int}, ...]
  # @raise [RoutingError] If optimization fails
  def optimize_route(origin, stops)
    return stops if stops.length <= 1

    begin
      # Use waypoint optimization from Directions API
      waypoint_indices = (0...stops.length).to_a

      result = @client.directions(
        origin: [origin[:lat], origin[:lng]],
        destination: [stops.last[:lat], stops.last[:lng]],
        waypoints: stops.map { |s| [s[:lat], s[:lng]] },
        optimize_waypoints: true
      ).first

      if result.blank? || result[:waypoint_order].blank?
        raise RoutingError, "Route optimization failed"
      end

      # Reorder stops based on optimization
      optimized_order = result[:waypoint_order]
      optimized_stops = optimized_order.map.with_index do |original_index, sequence|
        stops[original_index].merge(sequence: sequence + 1)
      end

      optimized_stops
    rescue Google::Maps::Error => e
      raise RoutingError, "Route optimization failed: #{e.message}"
    end
  end

  # ── Calculate ETA ──────────────────────────────────────────────────────────────
  # Calculates estimated time of arrival from current location to destination
  #
  # @param current_location [Hash] Current position {lat: Float, lng: Float}
  # @param destination [Hash] Destination {lat: Float, lng: Float}
  # @param traffic_model [String] 'best_guess' (default), 'pessimistic', 'optimistic'
  # @return [Hash] { duration_seconds: Int, duration_minutes: Int, distance_meters: Int }
  def calculate_eta(current_location, destination, traffic_model = 'best_guess')
    begin
      result = @client.distance_matrix(
        origins: [[current_location[:lat], current_location[:lng]]],
        destinations: [[destination[:lat], destination[:lng]]],
        mode: DEFAULT_DELIVERY_MODE,
        traffic_model: traffic_model,
        departure_time: Time.current
      )

      matrix = parse_distance_matrix(result)
      row = matrix.first&.first

      return {
        duration_seconds: row[:duration_s],
        duration_minutes: (row[:duration_s] / 60.0).round,
        distance_meters: row[:distance_m]
      } if row.present?

      raise RoutingError, "ETA calculation returned no results"
    rescue Google::Maps::Error => e
      raise RoutingError, "ETA calculation failed: #{e.message}"
    end
  end

  # ── Validate Address ───────────────────────────────────────────────────────────
  # Validates if address exists and extracts components
  #
  # @param address [String] Address to validate
  # @return [Hash] {valid: Boolean, formatted_address: String, components: Hash}
  def validate_address(address)
    begin
      result = @client.geocode(address: address).first

      if result.blank?
        return { valid: false, error: "Address not found" }
      end

      {
        valid: true,
        formatted_address: result[:formatted_address],
        latitude: result[:geometry][:location][:lat],
        longitude: result[:geometry][:location][:lng],
        components: parse_address_components(result[:address_components])
      }
    rescue Google::Maps::Error => e
      { valid: false, error: e.message }
    end
  end

  private

  # ── Parse Distance Matrix Response ─────────────────────────────────────────────
  def parse_distance_matrix(result)
    result[:rows].map do |row|
      row[:elements].map do |element|
        if element[:status] == 'OK'
          {
            distance_m: element[:distance][:value],
            duration_s: element[:duration][:value]
          }
        else
          {
            distance_m: nil,
            duration_s: nil,
            error: element[:status]
          }
        end
      end
    end
  end

  # ── Parse Route Response ───────────────────────────────────────────────────────
  def parse_route(result)
    leg = result[:legs].first
    polyline = result[:overview_polyline][:points]

    {
      distance_m: result[:legs].sum { |l| l[:distance][:value] },
      duration_s: result[:legs].sum { |l| l[:duration][:value] },
      polyline: polyline,
      total_distance_formatted: result[:legs].sum { |l| l[:distance][:value] }.to_s + "m",
      total_duration_formatted: result[:legs].sum { |l| l[:duration][:value] }.to_s + "s"
    }
  end

  # ── Parse Address Components ───────────────────────────────────────────────────
  def parse_address_components(components)
    parsed = {
      street: nil,
      city: nil,
      state: nil,
      postal_code: nil,
      country: nil
    }

    components.each do |component|
      case component[:types].first
      when 'route'
        parsed[:street] = component[:long_name]
      when 'administrative_area_level_2'
        parsed[:city] = component[:long_name]
      when 'administrative_area_level_1'
        parsed[:state] = component[:long_name]
      when 'postal_code'
        parsed[:postal_code] = component[:long_name]
      when 'country'
        parsed[:country] = component[:long_name]
      end
    end

    parsed
  end

  # ── Validate Configuration ─────────────────────────────────────────────────────
  def validate_config!
    unless ENV['GOOGLE_MAPS_API_KEY'].present?
      raise MapsConfigError,
            "Missing GOOGLE_MAPS_API_KEY in environment variables\n" \
            "Get API key from: https://console.cloud.google.com/\n" \
            "Enable: Maps SDK, Geocoding API, Distance Matrix API, Directions API"
    end
  end
end
