# app/services/billing/razorpay/webhook_processor.rb
#
# Entry point for all Razorpay webhook events.
#
# Usage (from controller):
#   result = Billing::Razorpay::WebhookProcessor.new(
#     raw_body:  request.raw_post,
#     signature: request.headers["X-Razorpay-Signature"],
#     payload:   JSON.parse(request.raw_post)
#   ).call
#
module Billing
  module Razorpay
    class WebhookProcessor
      SUPPORTED_EVENTS = %w[
        subscription.charged
        subscription.activated
        subscription.cancelled
        subscription.halted
        payment.failed
      ].freeze

      Result = Struct.new(:success?, :error, :skipped, keyword_init: true)

      def initialize(raw_body:, signature:, payload:)
        @raw_body  = raw_body
        @signature = signature
        @payload   = payload
      end

      # ── Main entry ─────────────────────────────────────────────────────────

      def call
        # 1. Verify HMAC signature
        unless valid_signature?
          Rails.logger.warn("[WebhookProcessor] Invalid Razorpay signature")
          return Result.new(success?: false, error: "Invalid signature", skipped: false)
        end

        event_type     = @payload["event"].to_s
        razorpay_event_id = @payload["id"].to_s

        # 2. Skip unsupported events gracefully
        unless SUPPORTED_EVENTS.include?(event_type)
          return Result.new(success?: true, error: nil, skipped: true)
        end

        # 3. Resolve organization from subscription
        organization, subscription = resolve_org_and_subscription

        unless organization
          Rails.logger.warn("[WebhookProcessor] Organization not found for event #{razorpay_event_id}")
          return Result.new(success?: false, error: "Organization not found", skipped: false)
        end

        # 4. Idempotency — find or create billing event record
        billing_event = BillingEvent.find_or_initialize_by(razorpay_event_id: razorpay_event_id)
        if billing_event.persisted?
          Rails.logger.info("[WebhookProcessor] Skipping duplicate event #{razorpay_event_id}")
          return Result.new(success?: true, error: nil, skipped: true)
        end

        billing_event.assign_attributes(
          organization: organization,
          subscription: subscription,
          event_type:   event_type,
          payload:      @payload
        )
        billing_event.save!

        # 5. Route to the appropriate handler
        handle_event(event_type, organization: organization, subscription: subscription)

        billing_event.mark_processed!

        Result.new(success?: true, error: nil, skipped: false)
      rescue StandardError => e
        Rails.logger.error("[WebhookProcessor] Error processing event: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        Result.new(success?: false, error: e.message, skipped: false)
      end

      private

      # ── Signature verification ──────────────────────────────────────────────

      def valid_signature?
        secret = ::Billing::RAZORPAY_WEBHOOK_SECRET
        return true if secret.blank? && Rails.env.test?  # skip in test unless configured

        ::Razorpay::Utility.verify_webhook_signature(
          @raw_body,
          @signature.to_s,
          secret
        )
      rescue ::Razorpay::Error
        false
      end

      # ── Org / Subscription resolution ──────────────────────────────────────

      def resolve_org_and_subscription
        # Try to find via subscription entity
        sub_entity = @payload.dig("payload", "subscription", "entity")
        rzp_sub_id = sub_entity&.fetch("id", nil)

        # Also check notes for organization_id (set when creating subscription)
        notes = sub_entity&.fetch("notes", {}) || {}
        org_id = notes["organization_id"]

        subscription = Subscription.find_by(razorpay_subscription_id: rzp_sub_id) if rzp_sub_id.present?
        organization = subscription&.organization ||
                       (org_id.present? ? Organization.find_by(id: org_id) : nil)

        [ organization, subscription ]
      end

      # ── Event routing ───────────────────────────────────────────────────────

      def handle_event(event_type, organization:, subscription:)
        handler_class = EVENT_HANDLERS[event_type]
        return unless handler_class

        handler_class.new(
          organization: organization,
          subscription: subscription,
          payload:      @payload
        ).call
      end

      EVENT_HANDLERS = {
        "subscription.charged"   => EventHandlers::SubscriptionCharged,
        "subscription.activated" => EventHandlers::SubscriptionActivated,
        "subscription.cancelled" => EventHandlers::SubscriptionCancelled,
        "subscription.halted"    => EventHandlers::PaymentFailed,   # halted = repeated failures
        "payment.failed"         => EventHandlers::PaymentFailed
      }.freeze
    end
  end
end
