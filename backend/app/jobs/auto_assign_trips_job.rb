# frozen_string_literal: true

class AutoAssignTripsJob
  include Sidekiq::Job
  sidekiq_options queue: 'operations', retry: 2

  # Runs daily at 6 PM (end of business day)
  # Auto-assigns all approved orders without trip assignments
  # to the best available trips or creates new trips
  #
  def perform
    Organization.active.find_each do |organization|
      auto_assign_pending_orders(organization)
    end
  rescue StandardError => error
    log_error("AutoAssignTripsJob failed", error)
    raise error # Retry
  end

  private

  def auto_assign_pending_orders(organization)
    # Get all approved orders without trip assignments
    pending_orders = organization.sales_orders
                                  .where(status: 'approved')
                                  .left_outer_joins(:trip_stop)
                                  .where(trip_stops: { id: nil })
                                  .order(created_at: :asc)

    assigned_count = 0
    failed_count = 0

    pending_orders.find_each do |order|
      begin
        # Get best trip for this order
        suggester = Delivery::TripAssignmentSuggester.new(
          sales_order: order,
          organization: organization,
          trip_date: order.delivery_date || Date.today
        )

        suggestions = suggester.get_suggestions

        # Execute the best suggestion
        if suggestions.any?
          best_suggestion = suggestions.first

          case best_suggestion[:type]
          when 'existing_trip'
            result = Delivery::AssignToTripService.call(
              order: order,
              trip_id: best_suggestion[:trip_id],
              user: find_system_user(organization),
              trip_date: order.delivery_date || Date.today
            )
          when 'new_trip'
            result = Delivery::AssignToTripService.call(
              order: order,
              driver_id: best_suggestion[:suggested_driver_id],
              user: find_system_user(organization),
              trip_date: order.delivery_date || Date.today
            )
          else
            next # Skip unknown suggestion type
          end

          if result.success?
            assigned_count += 1
            log_info("Order #{order.order_number} auto-assigned to trip #{result.trip.trip_number}")
          else
            failed_count += 1
            log_error("Auto-assign failed for order #{order.order_number}: #{result.errors.join(', ')}")
          end
        else
          failed_count += 1
          log_info("No trip suggestions for order #{order.order_number}")
        end
      rescue StandardError => error
        failed_count += 1
        log_error("Error auto-assigning order #{order.id}: #{error.message}", error)
      end
    end

    log_info("AutoAssignTripsJob completed for org #{organization.id}: " \
             "#{assigned_count} assigned, #{failed_count} failed")
  end

  def find_system_user(organization)
    # Find or create a system user for audit trail
    # In production, would use a dedicated service account
    organization.users
                .where(role: %w[admin owner])
                .order(:created_at)
                .first || organization.owner
  end

  def log_info(message)
    Rails.logger.info({
      job: 'AutoAssignTripsJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error = nil)
    Rails.logger.error({
      job: 'AutoAssignTripsJob',
      message: message,
      error: error&.message,
      backtrace: error&.backtrace&.[](0..4)
    }.to_json)
  end
end
