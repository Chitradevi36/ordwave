# ── Background Job: Log SMS Messages ───────────────────────────────────────────
# Stores SMS delivery logs for audit trail and troubleshooting

class LogSMSJob
  include Sidekiq::Job

  sidekiq_options retry: 2, dead: true

  def perform(phone_number:, message_body:, twilio_sid:, message_type: nil, **metadata)
    begin
      SMSLog.create!(
        phone_number: phone_number,
        message_body: message_body.to_s[0...160], # Store first 160 chars
        message_type: message_type,
        twilio_sid: twilio_sid,
        metadata: metadata,
        sent_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log SMS: #{e.message}")
      raise # Retry
    end
  end
end
