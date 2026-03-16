# frozen_string_literal: true

# Twilio SMS Configuration
# Manages SMS sending for invoices, dunning, payment reminders, etc.
#
# Environment Variables:
#   TWILIO_ACCOUNT_SID  — Twilio account ID (from console.twilio.com)
#   TWILIO_AUTH_TOKEN   — Twilio auth token (from console.twilio.com)
#   TWILIO_PHONE_NUMBER — Sender phone number (e.g., +1234567890)
#   SMS_GATEWAY_ENABLED — Set to 'true' to enable SMS sending (default: false)

module TwilioClient
  class << self
    attr_reader :client

    def initialize!
      account_sid = ENV.fetch('TWILIO_ACCOUNT_SID', nil)
      auth_token  = ENV.fetch('TWILIO_AUTH_TOKEN', nil)

      if account_sid.blank? || auth_token.blank?
        Rails.logger.warn('[TwilioClient] Credentials not configured. SMS sending disabled.')
        @client = nil
        return
      end

      @client = Twilio::REST::Client.new(account_sid, auth_token)
      Rails.logger.info('[TwilioClient] Initialized with account #{account_sid[0..6]}...')
    end

    def send_sms(phone_number:, message:)
      unless @client
        Rails.logger.error('[TwilioClient] Client not initialized. Cannot send SMS.')
        return false
      end

      unless phone_number.present? && message.present?
        Rails.logger.warn('[TwilioClient] Phone or message missing')
        return false
      end

      sender = ENV.fetch('TWILIO_PHONE_NUMBER', nil)
      unless sender.present?
        Rails.logger.error('[TwilioClient] TWILIO_PHONE_NUMBER not configured')
        return false
      end

      begin
        response = @client.messages.create(
          from: sender,
          to:   phone_number,
          body: message
        )

        Rails.logger.info("[TwilioClient] SMS sent to #{phone_number}: #{response.sid}")
        { success: true, message_id: response.sid }
      rescue Twilio::REST::TwilioError => e
        Rails.logger.error("[TwilioClient] Twilio error sending SMS to #{phone_number}: #{e.message}")
        { success: false, error: e.message }
      rescue StandardError => e
        Rails.logger.error("[TwilioClient] Unexpected error sending SMS: #{e.class} — #{e.message}")
        { success: false, error: e.message }
      end
    end

    def enabled?
      @client.present?
    end
  end
end

# Initialize on startup
TwilioClient.initialize! if defined?(Rails)
