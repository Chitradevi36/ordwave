# frozen_string_literal: true

class DeliveryEscalationActionJob
  include Sidekiq::Job
  sidekiq_options queue: 'operations', retry: 2

  # Handles escalated deliveries that have reached max attempts
  # Scheduled daily at 7 AM (after morning standup, before business hours)
  #
  # States:
  #   escalated + age < 7 days   → send customer options (auto-refund/reschedule/pickup)
  #   escalated + age >= 7 days  → auto-refund if no customer response
  #   escalated + age >= 14 days → alert ops manager (manual intervention needed)
  #
  def perform
    Organization.active.find_each do |organization|
      process_escalated_deliveries(organization)
    end
  rescue StandardError => error
    log_error("DeliveryEscalationActionJob failed", error)
    raise error # Retry
  end

  private

  def process_escalated_deliveries(organization)
    escalated = RescheduleDelivery
                 .where(organization_id: organization.id)
                 .where(status: 'escalated')
                 .order(created_at: :asc)

    escalated.find_each do |record|
      process_escalation(record, organization)
    end
  rescue StandardError => error
    log_error("Error processing escalated deliveries for org #{organization.id}", error)
  end

  def process_escalation(record, organization)
    days_escalated = (Date.current - record.created_at.to_date).to_i

    case days_escalated
    when 0..7
      # Days 1-7: Send customer "pick one" options
      send_customer_options(record, organization) unless already_notified_today?(record)

    when 8..14
      # Days 8-14: If no customer response, auto-refund
      handle_auto_refund(record, organization) unless refund_already_initiated?(record)

    else
      # Days 15+: Escalate to ops manager
      alert_ops_manager(record, organization)
    end
  rescue StandardError => error
    log_error("Error processing escalation for delivery #{record.id}", error)
  end

  def send_customer_options(record, organization)
    stop = record.trip_stop
    customer = stop.sales_order.customer
    order = stop.sales_order

    return unless customer && order

    # Send SMS with 3 options
    options_text = "Your delivery of #{order.order_number} failed. Choose one: " \
                   "1=Refund (₹#{order.total_amount.round(0)}), " \
                   "2=Reschedule #{(Date.current + 3.days).strftime('%b %d')}, " \
                   "3=Pickup at #{organization.primary_branch&.name || 'warehouse'}"

    if TwilioClient.enabled? && customer.phone.present?
      TwilioClient.send_sms(phone_number: customer.phone, message: options_text)
    end

    # Send email too
    if customer.email.present?
      DeliveryMailer.escalated_delivery_options(order, customer, organization).deliver_later
    end

    # Create in-app notification
    Notification.create(
      user_id: customer.main_contact_user_id, # If contact user exists
      organization_id: organization.id,
      title: 'Your Delivery - Choose an Option',
      body: options_text,
      notification_type: 'delivery_escalated_options',
      deep_link_url: "/orders/#{order.id}?action=escalation_options"
    ) if customer.main_contact_user_id.present?

    # Mark that we notified today (prevents retry spam)
    escalation_data = record.escalation_data || {}
    escalation_data['last_notification_sent_at'] = Date.current.to_s
    record.update(escalation_data: escalation_data)

    log_info("Escalated delivery options sent for stop #{stop.id}")
  rescue StandardError => error
    log_error("Error sending customer options for #{record.id}", error)
  end

  def handle_auto_refund(record, organization)
    stop = record.trip_stop
    order = stop.sales_order
    customer = order.customer

    return unless customer && order

    # Auto-refund the payment
    begin
      result = Payments::RefundService.call(
        order: order,
        organization: organization,
        reason: 'Delivery failed after max attempts'
      )

      if result.success?
        # Mark refund initiated
        escalation_data = record.escalation_data || {}
        escalation_data['refund_initiated_at'] = Time.current.iso8601
        escalation_data['refund_reason'] = 'Auto-refund after 7 days (customer no response)'
        record.update(
          escalation_data: escalation_data,
          status: 'refunded'
        )

        # Notify customer
        if customer.email.present?
          DeliveryMailer.refund_initiated(order, customer, organization).deliver_later
        end

        log_info("Auto-refund initiated for order #{order.id}")
      else
        # Refund failed, escalate to manager
        escalation_data = record.escalation_data || {}
        escalation_data['auto_refund_failed'] = result.errors.join(', ')
        record.update(escalation_data: escalation_data)

        alert_ops_manager(record, organization)
      end
    rescue StandardError => error
      log_error("Auto-refund failed for order #{order.id}: #{error.message}", error)
      alert_ops_manager(record, organization)
    end
  end

  def alert_ops_manager(record, organization)
    order = record.trip_stop.sales_order
    customer = order.customer
    days_escalated = (Date.current - record.created_at.to_date).to_i

    # Find ops/delivery manager
    manager = organization.users
                         .where(role: %w[owner admin manager])
                         .order('RAND()').first # Pick random manager if multiple

    return unless manager

    Notification.create(
      user: manager,
      organization: organization,
      title: "Delivery Escalation - Manual Action Needed",
      body: "Order #{order.order_number} from #{customer.name} undelivered for #{days_escalated} days. " \
            "Auto-options sent but no customer response.",
      notification_type: 'delivery_escalation_alert',
      deep_link_url: "/orders/#{order.id}?action=escalation_details",
      severity: days_escalated >= 14 ? 'high' : 'medium'
    )

    # Send manager SMS if alert is old (14+ days)
    if days_escalated >= 14 && TwilioClient.enabled? && manager.phone.present?
      TwilioClient.send_sms(
        phone_number: manager.phone,
        message: "URGENT: Order #{order.order_number} undelivered for #{days_escalated} days. " \
                 "Customer not responding to options. Manual intervention needed. #{organization.name}"
      )
    end

    log_info("Ops manager alert created for escalated delivery #{record.id}")
  rescue StandardError => error
    log_error("Error alerting ops manager for delivery #{record.id}", error)
  end

  def already_notified_today?(record)
    return false unless record.escalation_data&.dig('last_notification_sent_at')

    notified_date = Date.parse(record.escalation_data['last_notification_sent_at'])
    notified_date == Date.current
  rescue
    false
  end

  def refund_already_initiated?(record)
    record.escalation_data&.dig('refund_initiated_at').present?
  end

  def log_info(message)
    Rails.logger.info({
      job: 'DeliveryEscalationActionJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'DeliveryEscalationActionJob',
      message: message,
      error: error.message,
      backtrace: error.backtrace[0..4]
    }.to_json)
  end
end
