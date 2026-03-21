# frozen_string_literal: true

module Delivery
  # Handles rescheduling of failed deliveries.
  # When a delivery is marked as failed, this service:
  # 1. Creates or updates RescheduledDelivery record for tracking
  # 2. Optionally auto-creates a new trip for the next available date
  # 3. Notifies customer about the failure and rescheduling
  # 4. Tracks failure reasons and frequency
  #
  # Usage:
  #   result = Delivery::FailedDeliveryRescheduleService.call(
  #     trip_stop: stop,
  #     exception_code: 'customer_not_available',
  #     notes: 'Will retry tomorrow',
  #     auto_reschedule: true,
  #     actor: current_user
  #   )
  class FailedDeliveryRescheduleService
    Result = Struct.new(:success, :rescheduled_trip, :message, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(trip_stop:, exception_code:, notes: nil, auto_reschedule: true, actor: nil)
      @stop = trip_stop
      @exception_code = exception_code
      @notes = notes
      @auto_reschedule = auto_reschedule
      @actor = actor
      @errors = []
    end

    def call
      validate!
      return failure if errors_present?

      begin
        create_reschedule_record
        new_trip = auto_create_new_trip! if @auto_reschedule
        notify_customer
        success(new_trip)
      rescue StandardError => error
        log_error("Failed delivery rescheduling failed", error)
        failure("#{error.class}: #{error.message}")
      end
    end

    private

    def validate!
      @errors = []
      @errors << 'Trip stop not found' unless @stop.present?
      @errors << 'Delivery must be marked as failed' unless @stop.status == 'failed'
      @errors << 'Exception code required' if @exception_code.blank?
    end

    def errors_present?
      @errors.any?
    end

    def create_reschedule_record
      organization = @stop.delivery_trip.organization
      sales_order = @stop.sales_order
      customer = sales_order.customer

      # Create or update rescheduled delivery record
      @reschedule_record = RescheduleDelivery.find_or_initialize_by(
        trip_stop: @stop,
        sales_order: sales_order
      )

      @reschedule_record.assign_attributes(
        organization: organization,
        customer: customer,
        original_date: @stop.delivery_trip.trip_date,
        failure_code: @exception_code,
        failure_notes: @notes,
        attempt_count: (@reschedule_record.attempt_count || 0) + 1,
        last_attempted_at: @stop.delivered_at,
        next_retry_date: calculate_next_retry_date,
        status: 'pending'
      )

      @reschedule_record.save!
    end

    def auto_create_new_trip!
      sales_order = @stop.sales_order
      organization = @stop.delivery_trip.organization
      trip = @stop.delivery_trip

      # Determine next trip date (next day, or later if order has special constraints)
      next_trip_date = calculate_next_retry_date.to_date

      # Create new trip for next available date
      new_trip = create_trip_for_reschedule(organization, trip, next_trip_date)
      return nil unless new_trip

      # Add stop to new trip
      new_stop = TripStop.create!(
        delivery_trip: new_trip,
        sales_order: sales_order,
        sequence: new_trip.stops.maximum(:sequence).to_i + 1,
        status: 'pending'
      )

      # Record the reschedule relationship
      @reschedule_record.update(
        new_trip_stop: new_stop,
        new_trip_date: next_trip_date,
        rescheduled_at: Time.current
      )

      log_reschedule(organization, sales_order, new_trip)
      new_trip
    rescue StandardError => error
      # Log but don't fail - rescheduling failure shouldn't prevent marking delivery as failed
      Rails.logger.warn({
        service: 'Delivery::FailedDeliveryRescheduleService',
        action: 'auto_create_new_trip',
        stop_id: @stop.id,
        error: error.message
      }.to_json)
      nil
    end

    def create_trip_for_reschedule(organization, original_trip, trip_date)
      # Use TripAutoCreateService if available, or create manually
      result = Delivery::TripAutoCreateService.call(
        actor: @actor,
        organization: organization,
        trip_date: trip_date,
        branch: original_trip.branch,
        route: original_trip.route
      )

      return nil if !result[:ok] || result[:trips].empty?

      result[:trips].first
    rescue StandardError => error
      Rails.logger.error({
        service: 'Delivery::FailedDeliveryRescheduleService',
        action: 'create_trip_for_reschedule',
        error: error.message
      }.to_json)
      nil
    end

    def notify_customer
      organization = @stop.delivery_trip.organization
      order = @stop.sales_order
      customer = order.customer

      return unless customer.present?

      failure_reason = format_failure_reason(@exception_code)
      next_date = @reschedule_record.next_retry_date.strftime('%B %d, %Y')

      # Create in-app notification
      Notification.create(
        organization: organization,
        user_id: order.created_by_id,
        title: 'Delivery Failed - Rescheduled',
        body: "Order #{order.order_number} delivery failed (#{failure_reason}). Rescheduled for #{next_date}.",
        notification_type: 'delivery_rescheduled',
        deep_link_url: "/orders/#{order.id}"
      ) if order.created_by_id.present?

      # Feature 10: Enqueue SMS/Email notification to customer (async)
      # Sends SMS with rescheduled date and option to decline via SMS reply
      DeliveryFailureNotificationJob.perform_later(@reschedule_record.id)
    rescue => error
      Rails.logger.warn({
        service: 'Delivery::FailedDeliveryRescheduleService',
        action: 'notify_customer',
        error: error.message
      }.to_json)
    end

    def calculate_next_retry_date
      # Default: retry next business day
      next_date = (@stop.delivery_trip.trip_date + 1.day).next_occurring(:monday) if @stop.delivery_trip.trip_date.friday?
      next_date ||= @stop.delivery_trip.trip_date + 1.day

      # Check attempt count for increasing delays
      attempt_count = @reschedule_record&.attempt_count || 1
      case attempt_count
      when 2
        next_date + 2.days  # Second failure: retry in 3 days
      when 3
        next_date + 5.days  # Third failure: retry in 8 days
      else
        next_date
      end
    end

    def format_failure_reason(code)
      case code
      when 'customer_not_available'
        'Customer not available'
      when 'address_not_found'
        'Address not found'
      when 'refused_by_customer'
        'Refused by customer'
      when 'damaged_goods'
        'Goods damaged'
      when 'payment_not_ready'
        'Payment pending'
      when 'vehicle_breakdown'
        'Vehicle breakdown'
      when 'other'
        'Other reason'
      else
        'Delivery failed'
      end
    end

    def log_reschedule(organization, order, new_trip)
      Credit::AuditLogger.log(
        actor: @actor,
        organization: organization,
        auditable: order,
        action: 'delivery_failed_and_rescheduled',
        changes: {
          original_trip_id: @stop.delivery_trip.id,
          failure_code: @exception_code,
          new_trip_id: new_trip&.id,
          new_trip_date: new_trip&.trip_date,
          attempt_count: @reschedule_record.attempt_count
        },
        reason: "Delivery failed: #{format_failure_reason(@exception_code)}"
      )
    end

    def success(new_trip)
      Result.new(
        success: true,
        rescheduled_trip: new_trip,
        message: "Delivery rescheduled for #{@reschedule_record.next_retry_date&.strftime('%B %d, %Y')}",
        errors: []
      )
    end

    def failure(message = nil)
      Result.new(
        success: false,
        rescheduled_trip: nil,
        message: message,
        errors: @errors + [message].compact
      )
    end

    def log_error(message, error)
      Rails.logger.error({
        service: 'Delivery::FailedDeliveryRescheduleService',
        message: message,
        stop_id: @stop&.id,
        error: error.message,
        backtrace: error.backtrace[0..4]
      }.to_json)
    end
  end
end
