# frozen_string_literal: true

module Delivery
  # Suggests optimal trip assignments for a sales order
  # Finds the best available trip or recommends creating a new one
  #
  # Usage:
  #   suggester = Delivery::TripAssignmentSuggester.new(
  #     sales_order: order,
  #     organization: org,
  #     trip_date: Date.today
  #   )
  #   suggestions = suggester.get_suggestions
  #   # Returns:
  #   # [
  #   #   { type: 'existing_trip', score: 95, trip_id: X, trip_number: 'T123', ... },
  #   #   { type: 'new_trip', score: 80, suggested_driver_id: X, reason: '...' }
  #   # ]
  #
  class TripAssignmentSuggester
    MAX_STOPS_PER_TRIP = 15
    IDEAL_TRIP_WEIGHT = 10_000 # grams - adjust based on product mix

    def initialize(sales_order:, organization:, trip_date: Date.today)
      @order = sales_order
      @org = organization
      @trip_date = trip_date
      @customer_location = @order.delivery_address || @order.customer.primary_address
    end

    def get_suggestions
      suggestions = []

      # 1. Existing trips for same date/branch
      suggestions.concat(existing_trip_suggestions)

      # 2. New trip recommendations
      suggestions.concat(new_trip_suggestions)

      suggestions.sort_by { |s| -s[:score] }.first(3)
    end

    private

    def existing_trip_suggestions
      # Find open/planned trips for this branch on this date
      open_trips = @org.delivery_trips
                       .where(branch_id: @order.branch_id)
                       .where(trip_date: @trip_date)
                       .where(status: %w[draft planned])
                       .includes(:driver, :stops)
                       .where.not(driver_id: nil) # Must have a driver

      open_trips.map do |trip|
        score = calculate_trip_fit_score(trip)

        next unless score > 50 # Only suggest if reasonable fit

        {
          type: 'existing_trip',
          score: score,
          trip_id: trip.id,
          trip_number: trip.trip_number,
          driver_id: trip.driver_id,
          driver_name: trip.driver.name,
          existing_stops: trip.stops.count,
          estimated_stops_after: trip.stops.count + 1,
          distance_to_customer: distance_to_customer(trip),
          action: 'add_to_existing_trip',
          reason: score_explanation(trip, score)
        }
      end.compact
    end

    def new_trip_suggestions
      # Recommend creating a new trip with best-fit driver
      drivers = find_available_drivers
      return [] if drivers.empty?

      drivers.map do |driver|
        {
          type: 'new_trip',
          score: 75, # New trips get baseline score
          suggested_driver_id: driver.id,
          suggested_driver_name: driver.name,
          estimated_stops: 1,
          action: 'create_new_trip',
          reason: "Create new trip for #{driver.name}. #{distance_explanation(driver)}"
        }
      end.first(2) # Return top 2 driver options
    end

    def calculate_trip_fit_score(trip)
      score = 0

      # Factor 1: Capacity (30 points)
      stops_capacity = (1 - (trip.stops.count.to_f / MAX_STOPS_PER_TRIP)) * 30
      score += stops_capacity

      # Factor 2: Distance proximity (35 points) - closer is better
      avg_distance = calculate_average_distance_in_trip(trip)
      customer_distance = distance_to_customer(trip)
      
      if avg_distance > 0
        distance_score = (1 - (customer_distance / (avg_distance * 1.5))) * 35
        score += [distance_score, 35].min
      else
        # First stop in trip - high affinity
        score += 30
      end

      # Factor 3: Weight/volume match (20 points)
      weight_score = calculate_weight_fit(trip) * 20
      score += weight_score

      # Factor 4: Driver assignment stability (15 points)
      if trip.driver.present?
        # Driver already assigned increases likelihood of good route
        score += 10
      end

      score.round(1)
    end

    def calculate_average_distance_in_trip(trip)
      return 0 if trip.stops.empty?

      # Calculate average distance between consecutive stops
      stops = trip.stops.includes(:sales_order).map do |stop|
        addr = stop.sales_order.delivery_address || stop.sales_order.customer.primary_address
        { lat: addr.latitude, lon: addr.longitude }
      end

      return 0 if stops.count < 2

      total_distance = 0
      (0...stops.count - 1).each do |i|
        total_distance += haversine_distance(stops[i], stops[i + 1])
      end

      total_distance / (stops.count - 1)
    end

    def distance_to_customer(trip)
      return 0 if trip.stops.empty? || !@customer_location

      last_stop = trip.stops.includes(:sales_order).last
      last_location = {
        lat: last_stop.sales_order.delivery_address&.latitude || last_stop.sales_order.customer.primary_address.latitude,
        lon: last_stop.sales_order.delivery_address&.longitude || last_stop.sales_order.customer.primary_address.longitude
      }

      customer_location = {
        lat: @customer_location.latitude,
        lon: @customer_location.longitude
      }

      haversine_distance(last_location, customer_location)
    end

    def calculate_weight_fit(trip)
      trip_weight = trip.stops.sum { |s| s.sales_order.lines.sum(&:total_weight) }
      order_weight = @order.lines.sum(&:total_weight)

      # Perfect fit if  total ~= IDEAL_TRIP_WEIGHT
      total_weight = trip_weight + order_weight
      if total_weight > IDEAL_TRIP_WEIGHT * 1.2
        0.5 # Overweight, but still acceptable
      elsif total_weight < IDEAL_TRIP_WEIGHT * 0.8
        0.8 # Underweight, good room for more
      else
        1.0 # Perfect fit
      end
    end

    def haversine_distance(point1, point2)
      # Returns distance in km
      earth_radius = 6371 # km

      lat1_rad = point1[:lat] * Math::PI / 180
      lat2_rad = point2[:lat] * Math::PI / 180
      delta_lat = (point2[:lat] - point1[:lat]) * Math::PI / 180
      delta_lon = (point2[:lon] - point1[:lon]) * Math::PI / 180

      a = Math.sin(delta_lat / 2) ** 2 +
          Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lon / 2) ** 2

      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      earth_radius * c
    end

    def find_available_drivers
      # Find drivers who have trips on this date or are unassigned
      assigned_driver_ids = @org.delivery_trips
                                 .where(trip_date: @trip_date)
                                 .pluck(:driver_id)
                                 .uniq
                                 .compact

      # Get all active drivers, preferring those already working today
      active_drivers = @org.users
                           .where(role: %w[driver manager])
                           .where(deleted_at: nil)
                           .order_by do |u|
                             assigned_driver_ids.include?(u.id) ? 0 : 1 # Prefer those already assigned
                           end

      active_drivers.first(5) # Return top 5 candidates
    end

    def score_explanation(trip, score)
      components = []
      components << "#{trip.stops.count} existing stops"
      components << "Driver: #{trip.driver.name}" if trip.driver
      components << "#{distance_to_customer(trip).round(1)}km from last stop"
      
      "Good fit (score: #{score}). #{components.join(', ')}"
    end

    def distance_explanation(driver)
      "Assign to #{driver.name} for new trip."
    end
  end
end
