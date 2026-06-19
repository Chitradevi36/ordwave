class NotifyGoogleChatJob
  include Sidekiq::Worker
  sidekiq_options queue: 'notifications', retry: 3

  # event_hash should be a simple Hash representation of the Sentry event
  def perform(event_hash = {})
    return unless ENV['GOOGLE_CHAT_WEBHOOK_URL']

    begin
      title = event_hash.dig('exception', 0, 'type') || event_hash['message'] || 'Error'
      level = event_hash['level'] || 'error'
      culprit = event_hash['culprit'] || event_hash.dig('exception', 0, 'value')
      event_id = event_hash['event_id'] || event_hash['id']

      text = "[#{level.upcase}] #{title} — #{culprit}\nEvent: #{event_id}\nProject: #{event_hash['project'] || event_hash['logger'] || 'app'}"

      # include URL to Sentry if available
      if event_hash['url']
        text += "\nSentry: #{event_hash['url']}"
      elsif event_id && ENV['SENTRY_DSN']
        # best-effort Sentry issue link format (may vary by Sentry setup)
        text += "\nSentry event id: #{event_id}"
      end

      Notifications::GoogleChatService.post_text(text)
    rescue => e
      Rails.logger.error("[NotifyGoogleChatJob] failed: #{e.class}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
    end
  end
end
