require 'twilio-ruby'

# ── SMS Service ────────────────────────────────────────────────────────────────
# Handles all SMS/OTP communications via Twilio
# Supports: OTP verification, delivery notifications, payment reminders

class SmsService
  # ── Errors ───────────────────────────────────────────────────────────────────
  class TwilioConfigError < StandardError; end
  class SMSSendError < StandardError; end

  # ── Constants ──────────────────────────────────────────────────────────────────
  OTP_MESSAGE_TEMPLATE = "Your OTP for %{context} is: %{otp}. Valid for 10 minutes. Do not share with anyone."
  DELIVERY_MESSAGE_TEMPLATE = "Trip %{trip_number} assigned. Click: %{tracking_link}"
  PAYMENT_REMINDER_TEMPLATE = "Payment due: ₹%{amount} for invoice %{invoice_number}. Pay now: %{payment_link}"

  def initialize
    validate_config!
    @client = Twilio::REST::Client.new(
      ENV.fetch('TWILIO_ACCOUNT_SID'),
      ENV.fetch('TWILIO_AUTH_TOKEN')
    )
    @from_number = ENV.fetch('TWILIO_PHONE_NUMBER')
  end

  # ── Send OTP for Delivery Proof ────────────────────────────────────────────────
  # Sends OTP to driver's phone for delivery verification
  #
  # @param phone_number [String] Driver's phone number (with country code +91)
  # @param otp_code [String] 6-digit OTP
  # @param delivery_stop_id [Integer] Stop ID for context
  # @return [String] Twilio message SID on success
  # @raise [SMSSendError] If Twilio API call fails
  def send_delivery_otp(phone_number, otp_code, delivery_stop_id = nil)
    message = format(
      OTP_MESSAGE_TEMPLATE,
      context: "delivery confirmation",
      otp: otp_code
    )

    send_sms(phone_number, message, {
      delivery_stop_id: delivery_stop_id,
      message_type: 'delivery_otp'
    })
  end

  # ── Send Registration OTP ──────────────────────────────────────────────────────
  # Sends OTP to user's phone for account verification
  #
  # @param phone_number [String] User's phone number
  # @param otp_code [String] 6-digit OTP
  # @return [String] Twilio message SID
  def send_registration_otp(phone_number, otp_code)
    message = format(
      OTP_MESSAGE_TEMPLATE,
      context: "account verification",
      otp: otp_code
    )

    send_sms(phone_number, message, {
      message_type: 'registration_otp'
    })
  end

  # ── Send Login OTP ─────────────────────────────────────────────────────────────
  # Sends OTP to user's phone for login verification
  #
  # @param phone_number [String] User's phone number
  # @param otp_code [String] 6-digit OTP
  # @return [String] Twilio message SID
  def send_login_otp(phone_number, otp_code)
    message = format(
      OTP_MESSAGE_TEMPLATE,
      context: "login",
      otp: otp_code
    )

    send_sms(phone_number, message, {
      message_type: 'login_otp'
    })
  end

  # ── Send Delivery Alert ────────────────────────────────────────────────────────
  # Notifies driver that a new trip/delivery is assigned
  #
  # @param phone_number [String] Driver's phone
  # @param trip_number [String] Trip identifier
  # @param tracking_link [String] URL to trip details
  # @return [String] Twilio message SID
  def send_delivery_alert(phone_number, trip_number, tracking_link)
    message = format(
      DELIVERY_MESSAGE_TEMPLATE,
      trip_number: trip_number,
      tracking_link: tracking_link
    )

    send_sms(phone_number, message, {
      trip_number: trip_number,
      message_type: 'delivery_alert'
    })
  end

  # ── Send Payment Reminder ──────────────────────────────────────────────────────
  # Sends payment due reminder to customers
  #
  # @param phone_number [String] Customer's phone
  # @param invoice_number [String] Invoice ID
  # @param amount [Float] Outstanding amount
  # @param payment_link [String] Payment URL
  # @return [String] Twilio message SID
  def send_payment_reminder(phone_number, invoice_number, amount, payment_link)
    message = format(
      PAYMENT_REMINDER_TEMPLATE,
      invoice_number: invoice_number,
      amount: amount.to_i,
      payment_link: payment_link
    )

    send_sms(phone_number, message, {
      invoice_number: invoice_number,
      message_type: 'payment_reminder'
    })
  end

  # ── Send Custom SMS ────────────────────────────────────────────────────────────
  # Generic SMS sender for custom messages
  #
  # @param phone_number [String] Recipient phone
  # @param message [String] Message content (max 160 chars recommended)
  # @param metadata [Hash] Optional metadata for logging
  # @return [String] Twilio message SID
  def send_custom_sms(phone_number, message, metadata = {})
    send_sms(phone_number, message, metadata.merge(message_type: 'custom'))
  end

  private

  # ── Internal SMS Sender ────────────────────────────────────────────────────────
  # Sends SMS via Twilio API
  #
  # @param phone_number [String] Recipient phone (with country code)
  # @param message [String] Message content
  # @param metadata [Hash] Extra data for logging/tracking
  # @return [String] Message SID
  # @raise [SMSSendError] If API call fails
  def send_sms(phone_number, message, metadata = {})
    begin
      # Ensure phone number has country code
      phone_number = normalise_phone_number(phone_number)

      # Send SMS
      response = @client.messages.create(
        from: @from_number,
        to: phone_number,
        body: message
      )

      # Log SMS in background job
      LogSmsJob.perform_later(
        phone_number: phone_number,
        message_body: message,
        twilio_sid: response.sid,
        **metadata
      )

      response.sid
    rescue Twilio::REST::TwilioError => e
      error_msg = "Failed to send SMS to #{phone_number}: #{e.message}"
      Rails.logger.error(error_msg)
      raise SMSSendError, error_msg
    rescue StandardError => e
      error_msg = "Unexpected error sending SMS: #{e.message}"
      Rails.logger.error(error_msg)
      raise SMSSendError, error_msg
    end
  end

  # ── Validate Configuration ─────────────────────────────────────────────────────
  # Ensures all required Twilio env vars are set
  def validate_config!
    required_keys = %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_PHONE_NUMBER]
    missing_keys = required_keys.reject { |key| ENV[key].present? }

    if missing_keys.any?
      raise TwilioConfigError,
            "Missing SMS configuration: #{missing_keys.join(', ')}\n" \
            "Add to .env: #{missing_keys.map { |k| "#{k}=..." }.join(', ')}"
    end
  end

  # ── Normalize Phone Number ──────────────────────────────────────────────────────
  # Ensures phone number has country code (Twilio requirement)
  #
  # @param phone_number [String] Phone to normalize
  # @return [String] Valid Twilio format (+<country_code><number>)
  def normalise_phone_number(phone_number)
    # Remove any non-digit characters except +
    clean = phone_number.gsub(/[^\d+]/, '')

    # If already has +, return as-is
    return clean if clean.start_with?('+')

    # India: assume +91 if no country code
    # Remove leading 0 if present
    clean = clean.sub(/^0+/, '') if clean.start_with?('0')

    # Add India country code
    "+91#{clean.slice(-10, 10)}"
  end
end
