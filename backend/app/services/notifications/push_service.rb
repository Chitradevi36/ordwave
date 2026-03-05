module Notifications
  # Sends push notifications via Firebase Cloud Messaging (FCM).
  #
  # Usage — broadcast to all active tokens for a user:
  #   Notifications::PushService.notify_user(
  #     user:         user,
  #     organization: org,
  #     title:        "Order Approved",
  #     body:         "Order #ORD-001 has been approved.",
  #     data:         { order_id: 123 }
  #   )
  #
  # Usage — broadcast to all active tokens in an org:
  #   Notifications::PushService.notify_org(
  #     organization: org,
  #     title:        "⚠️ Low Stock Alert",
  #     body:         "Product SKU-001 is below minimum threshold.",
  #     data:         { product_id: 5 }
  #   )
  #
  class PushService
    FCM_SERVER_KEY = ENV.fetch("FCM_SERVER_KEY", nil)

    Result = Struct.new(:success?, :sent_count, :failed_tokens, :errors)

    def self.notify_user(user:, organization:, title:, body:, data: {})
      tokens = DeviceToken
                 .active
                 .for_user(user)
                 .for_org(organization)
                 .pluck(:token)

      new(tokens: tokens, title: title, body: body, data: data).deliver
    end

    def self.notify_org(organization:, title:, body:, data: {})
      tokens = DeviceToken
                 .active
                 .for_org(organization)
                 .pluck(:token)

      new(tokens: tokens, title: title, body: body, data: data).deliver
    end

    def initialize(tokens:, title:, body:, data: {})
      @tokens = Array(tokens).compact.uniq
      @title  = title
      @body   = body
      @data   = data.transform_values(&:to_s)
    end

    def deliver
      return Result.new(true, 0, [], []) if @tokens.empty?
      return Result.new(false, 0, [], ["FCM_SERVER_KEY is not configured"]) unless FCM_SERVER_KEY

      client = FCM.new(FCM_SERVER_KEY)

      failed_tokens = []
      sent_count    = 0

      # FCM supports up to 1000 tokens per batch
      @tokens.each_slice(1000) do |batch|
        response = client.send_v1(
          {
            notification: { title: @title, body: @body },
            data:         @data,
          },
          registration_ids: batch
        )

        if response[:status_code] == 200
          body = response[:body]
          body_json = JSON.parse(body) rescue {}

          (body_json["results"] || []).each_with_index do |result, i|
            if result["error"]
              failed_tokens << batch[i]
              deactivate_token(batch[i]) if unregistered_error?(result["error"])
            else
              sent_count += 1
            end
          end
        else
          Rails.logger.error("[PushService] FCM returned #{response[:status_code]}: #{response[:body]}")
          failed_tokens.concat(batch)
        end
      end

      Result.new(failed_tokens.empty?, sent_count, failed_tokens, [])
    rescue => e
      Sentry.capture_exception(e) if defined?(Sentry)
      Rails.logger.error("[PushService] #{e.class}: #{e.message}")
      Result.new(false, 0, [], [e.message])
    end

    private

    # Remove tokens that FCM says are no longer valid
    def deactivate_token(token)
      DeviceToken.where(token: token).update_all(active: false)
      Rails.logger.info("[PushService] Deactivated stale token: #{token.truncate(20)}")
    end

    def unregistered_error?(error_code)
      %w[NotRegistered InvalidRegistration].include?(error_code)
    end
  end
end
