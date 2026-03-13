# app/controllers/api/v1/webhooks/razorpay_controller.rb
#
# Receives Razorpay webhook events and delegates to the processor.
#
# NOTE: This controller inherits from ActionController::Base — NOT the API
# base controller — because:
#   1. It must not require JWT authentication.
#   2. It needs access to `request.raw_post` for HMAC signature verification.
#      Middleware that parses the body before this runs would break verification.
#
# Security: authentication is done via HMAC signature (X-Razorpay-Signature).
#
module Api
  module V1
    module Webhooks
      class RazorpayController < ActionController::Base
        # Disable CSRF for webhook endpoint (authenticated via HMAC instead)
        skip_before_action :verify_authenticity_token

        def receive
          raw_body  = request.raw_post
          signature = request.headers["X-Razorpay-Signature"].to_s

          payload = begin
            JSON.parse(raw_body)
          rescue JSON::ParserError
            return render json: { error: "Invalid JSON" }, status: :bad_request
          end

          result = Billing::Razorpay::WebhookProcessor.new(
            raw_body:  raw_body,
            signature: signature,
            payload:   payload
          ).call

          if result.success?
            render json: { status: "ok" }, status: :ok
          elsif result.skipped
            render json: { status: "skipped" }, status: :ok
          else
            # Return 200 for "organization not found" so Razorpay doesn't retry
            # endlessly. Log the error for investigation.
            render json: { status: "error", message: result.error }, status: :ok
          end
        end
      end
    end
  end
end
