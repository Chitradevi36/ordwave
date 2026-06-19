# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Notifications
  # Posts simple messages or cards to a Google Chat incoming webhook.
  #
  # Configure via `GOOGLE_CHAT_WEBHOOK_URL` in env/credentials.
  class GoogleChatService
    WEBHOOK_URL = ENV.fetch('GOOGLE_CHAT_WEBHOOK_URL', nil)

    def self.post_text(text)
      return unless WEBHOOK_URL
      new(WEBHOOK_URL).post_text(text)
    end

    def initialize(webhook_url)
      @uri = URI.parse(webhook_url)
    end

    def post_text(text)
      payload = { text: text }.to_json
      post(payload)
    end

    def post_card(card_json)
      # accepts a Hash or JSON string representing the cards payload
      payload = if card_json.is_a?(String)
                  card_json
                else
                  { cards: Array(card_json) }.to_json
                end

      post(payload)
    end

    private

    def post(payload)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = (@uri.scheme == 'https')
      req = Net::HTTP::Post.new(@uri.request_uri, 'Content-Type' => 'application/json')
      req.body = payload

      resp = http.request(req)
      unless resp.code.to_i.between?(200, 299)
        Rails.logger.error("[GoogleChatService] webhook failed: #{resp.code} #{resp.body}")
      else
        Rails.logger.info("[GoogleChatService] posted to chat (status=#{resp.code})")
      end
      resp
    rescue => e
      Rails.logger.error("[GoogleChatService] error: #{e.class}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
      nil
    end
  end
end
