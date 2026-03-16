# frozen_string_literal: true

# OSRM (Open Source Routing Machine) configuration
# For local development: docker run -p 5000:5000 osrm/osrm-backend
# For production: Use OSRM Cloud or self-hosted instance

OSRM_CONFIG = {
  enabled: ENV.fetch('OSRM_ENABLED', 'true') == 'true',
  endpoint: ENV.fetch('OSRM_ENDPOINT', 'http://localhost:5000'),
  service: ENV.fetch('OSRM_SERVICE', 'routed'), # 'routed' or 'car' etc
  profile: ENV.fetch('OSRM_PROFILE', 'car'),     # 'car', 'foot', 'bike'
  timeout: ENV.fetch('OSRM_TIMEOUT', '30').to_i,
  max_stops_per_request: 100  # OSRM limit
}.freeze

# Validate OSRM endpoint connectivity (lazy-loaded on first request)
module OSRMValidator
  class << self
    def reachable?
      return @osrm_reachable if defined?(@osrm_reachable)

      begin
        @osrm_reachable = OSRMClient.new.health_check
      rescue StandardError => e
        Rails.logger.warn("OSRM health check failed: #{e.message}")
        @osrm_reachable = false
      end

      @osrm_reachable
    end
  end
end

# OSRM HTTP Client
class OSRMClient
  def initialize
    @base_url = OSRM_CONFIG[:endpoint]
    @service = OSRM_CONFIG[:service]
    @profile = OSRM_CONFIG[:profile]
    @timeout = OSRM_CONFIG[:timeout]
  end

  # Check if OSRM service is available
  def health_check
    url = "#{@base_url}/status"
    response = make_request(url)
    response.is_a?(Hash) && response['code'] == 'Ok'
  rescue StandardError => e
    Rails.logger.error("OSRM health check error: #{e.message}")
    false
  end

  # Get route between two coordinates
  # Returns distance (meters) and duration (seconds)
  def route(from_lat, from_lon, to_lat, to_lon)
    coords = "#{from_lon},#{from_lat};#{to_lon},#{to_lat}"
    url = "#{@base_url}/#{@service}/v1/#{@profile}/route/#{coords}"
    params = { overview: 'false', steps: 'false', geometries: 'geojson' }
    
    response = make_request(url, params)
    
    if response['code'] == 'Ok' && response['routes'].any?
      route_data = response['routes'][0]
      {
        distance: route_data['distance'].to_f,
        duration: route_data['duration'].to_f,
        geometry: route_data['geometry']
      }
    else
      raise StandardError, "OSRM routing failed: #{response['message']}"
    end
  end

  # Optimize trip stop sequence (Travelling Salesman Problem)
  # coordinates: array of [lon, lat] pairs
  # Returns optimized indices
  def trip(coordinates, options = {})
    raise ArgumentError, "Maximum 100 stops supported by OSRM" if coordinates.size > 100

    # Convert to OSRM format: lon1,lat1;lon2,lat2;...
    coords_str = coordinates.map { |c| "#{c[0]},#{c[1]}" }.join(';')
    
    url = "#{@base_url}/#{@service}/v1/#{@profile}/trip/#{coords_str}"
    params = {
      overview: 'false',
      steps: 'false',
      geometries: 'geojson',
      annotations: 'duration,distance'
    }
    params.merge!(options) if options.any?

    response = make_request(url, params)

    if response['code'] == 'Ok'
      {
        waypoints: response['waypoints'],          # [{ hint, distance, name, location: [lon, lat] }, ...]
        routes: response['routes'],                # optimized routes
        trips: response['trips'].presence          # trips array if available
      }
    else
      raise StandardError, "OSRM trip optimization failed: #{response['message']}"
    end
  end

  # Matrix service: get distances/durations between multiple points
  def matrix(coordinates, options = {})
    raise ArgumentError, "Maximum 100 locations supported by OSRM" if coordinates.size > 100

    coords_str = coordinates.map { |c| "#{c[0]},#{c[1]}" }.join(';')
    url = "#{@base_url}/#{@service}/v1/#{@profile}/matrix/#{coords_str}"
    params = {
      annotations: 'distance,duration'
    }
    params.merge!(options) if options.any?

    response = make_request(url, params)

    if response['code'] == 'Ok'
      {
        distances: response['distances'],  # matrix of distances (meters)
        durations: response['durations'],   # matrix of durations (seconds)
        sources: response['sources'],
        destinations: response['destinations']
      }
    else
      raise StandardError, "OSRM matrix failed: #{response['message']}"
    end
  end

  private

  def make_request(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = @timeout
    http.open_timeout = @timeout

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("OSRM request failed to #{url}: #{e.message}")
    raise e
  end
end
