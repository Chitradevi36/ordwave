# frozen_string_literal: true

class DeliveryFailureNotificationJob
  include Sidekiq::Job
  sidekiq_options queue: 'notifications', retry: 3

  # Sends SMS notification to customer when delivery attempt fails
  # Scheduled immediately after failed delivery is marked
  #
  # Notifies customer with:
  # - Failure notification
  # - Rescheduled date (+3 days by default)
  # - Option to decline reschedule via SMS reply
  #
  def perform(reschedule_delivery_id)
    reschedule = RescheduleDelivery.find(reschedule_delivery_id)
    notify_customer(reschedule)
  rescue StandardError => error
    log_error("DeliveryFailureNotificationJob failed for reschedule #{reschedule_delivery_id}", error)
    raise error # Retry
  end

  private

  def notify_customer(reschedule)
    stop = reschedule.trip_stop
    order = reschedule.sales_order
    customer = order.customer
    organization = reschedule.organization

    return unless customer && order && stop

    # Skip if customer already notified for this failure (prevent spam)
    return if already_notified_today?(reschedule)

    # Build notification message
    reschedule_date = reschedule.next_retry_date || (Date.current + 3.days)
    formatted_date = reschedule_date.strftime('%b %d')

    message = build_failure_notification_message(order, reschedule, reschedule_date, formatted_date)

    # Send SMS if enabled and phone present
    if TwilioClient.enabled? && customer.phone.present?
      begin
        TwilioClient.send_sms(
          phone_number: customer.phone,
          message: message
        )
        log_info("Delivery failure SMS sent to #{customer.name} (#{customer.phone}) for order #{order.order_number}")
      rescue StandardError => error
        log_warn("Failed to send SMS to #{customer.phone}: #{error.message}")
        # Fall back to email
      end
    end

    # Send email as well
    if customer.email.present?
      begin
        DeliveryMailer.delivery_failed_notification(order, customer, reschedule_date, organization)
                      .deliver_later
        log_info("Delivery failure email sent to #{customer.email} for order #{order.order_number}")
      rescue StandardError => error
        log_warn("Failed to send email to #{customer.email}: #{error.message}")
      end
    end

    # Create in-app notification
    begin
      Notification.create(
        organization_id: organization.id,
        user_id: customer.main_contact_user_id,
        title: 'Delivery Update',
        body: "Your delivery for #{order.order_number} couldn't be completed. We've rescheduled it for #{formatted_date}.",
        notification_type: 'delivery_failed',
        deep_link_url: "/orders/#{order.id}?action=rescheduled_delivery",
        severity: 'medium'
      ) if customer.main_contact_user_id.present?
    rescue StandardError => e
      log_warn("Failed to create in-app notification: #{e.message}")
    end

    # Mark that we notified today (prevent spam)
    notification_data = reschedule.notification_data || {}
    notification_data['failure_notification_sent_at'] = Time.current.iso8601
    notification_data['failure_code'] = reschedule.failure_code
    reschedule.update(notification_data: notification_data)

    log_info("Delivery failure notification completed for reschedule_delivery #{reschedule.id}")
  rescue StandardError => error
    log_error("Error in notify_customer for reschedule #{reschedule.id}", error)
    raise error
  end

  def build_failure_notification_message(order, reschedule, reschedule_date, formatted_date)
    failure_reason = reschedule.failure_code.humanize if reschedule.failure_code
    organization = reschedule.organization

    # Craft message with rescheduled date and instructions
    if reschedule.failure_code == 'customer_not_available'
      "Hi #{order.customer.first_name}, your #{organization.name} delivery of #{order.order_number} " \
        "couldn't be completed today (not available). We've rescheduled it for #{formatted_date}. " \
        "Reply DECLINE to change the date."
    elsif reschedule.failure_code == 'address_not_found'
      "Hi #{order.customer.first_name}, we couldn't locate your delivery address for #{order.order_number}. " \
        "We're retrying on #{formatted_date}. Reply DECLINE if you'd like to change the address."
    else
      "Hi #{order.customer.first_name}, your delivery for #{order.order_number} " \
        "couldn't be completed today. We've rescheduled it for #{formatted_date}. " \
        "Reply DECLINE to reschedule."
    end
  end

  def already_notified_today?(reschedule)
    return false unless reschedule.notification_data&.dig('failure_notification_sent_at')

    notified_at = Time.parse(reschedule.notification_data['failure_notification_sent_at'])
    notified_at.to_date == Date.current
  rescue
    false
  end

  def log_info(message)
    Rails.logger.info({
      job: 'DeliveryFailureNotificationJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_warn(message)
    Rails.logger.warn({
      job: 'DeliveryFailureNotificationJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'DeliveryFailureNotificationJob',
      message: message,
      error: error.message,
      backtrace: error.backtrace[0..4]
    }.to_json)
  end
end
