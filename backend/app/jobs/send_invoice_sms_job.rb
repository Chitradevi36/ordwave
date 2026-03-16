# frozen_string_literal: true

# Sends invoice notification SMS to customer asynchronously.
#
# Triggered by:
#   - Invoice::GenerateFromDeliveryService after email is sent
#   - SalesInvoicesController create action
#
# Only sends if:
#   - Feature flag FEATURES.invoice_sms_notifications_enabled? is true
#   - Customer has a phone number
#   - Twilio is configured
#
# Retries up to 3 times on transient failures
# Discards silently on permanent failures (invalid phone, SMS disabled, etc)
#
class SendInvoiceSmsJob < ApplicationJob
  queue_as :sms

  # Retry on transient errors (network, Twilio overload, etc)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Discard silently if record is deleted
  discard_on_record_not_found

  # @param invoice_id [Integer] SalesInvoice id
  # @param recipient_phone [String] Phone number to send to (optional, uses invoice.customer.phone)
  def perform(invoice_id, recipient_phone = nil)
    invoice = SalesInvoice.find(invoice_id)

    # Skip if feature disabled
    unless FEATURES.invoice_sms_notifications_enabled?(invoice.organization)
      return
    end

    # Skip if Twilio not configured
    unless TwilioClient.enabled?
      Rails.logger.warn("[SendInvoiceSmsJob] Twilio not configured, skipping SMS for invoice #{invoice_id}")
      return
    end

    # Get phone number
    phone_number = recipient_phone || invoice.customer&.phone
    unless phone_number.present?
      Rails.logger.debug("[SendInvoiceSmsJob] No phone number for invoice #{invoice_id}")
      return
    end

    # Build SMS message
    message = build_invoice_sms_message(invoice)

    # Send via Twilio
    result = TwilioClient.send_sms(phone_number: phone_number, message: message)

    if result[:success]
      Rails.logger.info("[SendInvoiceSmsJob] SMS sent for invoice #{invoice_id} to #{phone_number}")
    else
      Rails.logger.error("[SendInvoiceSmsJob] SMS send failed for invoice #{invoice_id}: #{result[:error]}")
      # Re-raise so retry logic kicks in
      raise "SMS send failed: #{result[:error]}"
    end
  end

  private

  def build_invoice_sms_message(invoice)
    invoice_number = invoice.invoice_number
    amount = number_with_precision(invoice.total_amount, precision: 2)
    org_name = invoice.organization.name
    payment_url = invoice_payment_url(invoice)

    # Keep message under 160 characters (SMS limit)
    # This is a template; adjust based on your needs
    message = "Hi #{invoice.customer&.name}, " \
              "Invoice #{invoice_number} for ₹#{amount} from #{org_name} is ready. " \
              "Pay here: #{payment_url}"

    # If message is too long, truncate non-critical parts
    if message.length > 160
      message = "Invoice #{invoice_number} for ₹#{amount} is ready. " \
                "Pay: #{payment_url}"
    end

    if message.length > 160
      message = "Invoice #{invoice_number} ready. Pay: #{payment_url}"
    end

    message
  end

  # Helper to format currency (same as in views)
  def number_with_precision(number, precision: 2)
    number.nil? ? '' : sprintf("%.#{precision}f", number)
  end

  # Helper to build invoice payment URL
  # Adjust based on your frontend URL structure
  def invoice_payment_url(invoice)
    # Example: https://app.orderlane.pro/invoices/12345/pay
    "#{ENV.fetch('FRONTEND_URL', 'https://app.orderlane.pro')}/invoices/#{invoice.id}/pay"
  end
end
