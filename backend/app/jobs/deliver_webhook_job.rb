require "net/http"

# Delivers a single webhook payload to its endpoint URL.
# Signs the payload with HMAC-SHA256 and records the result.
#
# Auto-disables endpoints with 10+ consecutive failures.
#
class DeliverWebhookJob < ApplicationJob
  queue_as :critical

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  TIMEOUT_SECONDS = 10

  # @param delivery_id [Integer] WebhookDelivery id
  def perform(delivery_id)
    delivery = WebhookDelivery.includes(:webhook_endpoint).find(delivery_id)
    endpoint = delivery.webhook_endpoint

    return if endpoint.nil? || !endpoint.active?

    payload_json = delivery.payload.to_json

    signature = endpoint.signing_signature(payload_json)

    uri            = URI.parse(endpoint.url)
    http           = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl   = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri.path.presence || "/")
    request["Content-Type"]     = "application/json"
    request["X-OrderLane-Event"]     = delivery.event
    request["X-OrderLane-Signature"] = "sha256=#{signature}"
    request["X-OrderLane-Delivery"]  = delivery.id.to_s
    request.body = payload_json

    response = http.request(request)

    delivery.increment!(:attempt_count)

    if response.code.to_i.between?(200, 299)
      delivery.update!(
        status:        "delivered",
        response_code: response.code.to_i,
        response_body: response.body.to_s.truncate(2000),
        delivered_at:  Time.current
      )
      endpoint.update_columns(
        failure_count:   0,
        last_success_at: Time.current
      )
      Rails.logger.info("[DeliverWebhookJob] Delivery##{delivery_id} delivered — #{response.code}")
    else
      handle_failure(delivery, endpoint, response.code.to_i, response.body.to_s.truncate(2000))
    end
  rescue => e
    delivery&.increment!(:attempt_count)
    handle_failure(delivery, delivery&.webhook_endpoint, 0, e.message)
    raise   # re-raise so ActiveJob retry logic fires
  end

  private

  def handle_failure(delivery, endpoint, code, body)
    delivery&.update!(
      status:           "failed",
      response_code:    code,
      response_body:    body.truncate(2000),
    )
    return unless endpoint

    new_count = endpoint.failure_count + 1
    endpoint.update_columns(
      failure_count:       new_count,
      last_failure_at:     Time.current,
      last_failure_reason: body.truncate(500)
    )
    endpoint.disable_due_to_failures! if new_count >= 10

    Rails.logger.warn("[DeliverWebhookJob] Delivery##{delivery&.id} failed — #{code}: #{body.truncate(200)}")
  end
end
