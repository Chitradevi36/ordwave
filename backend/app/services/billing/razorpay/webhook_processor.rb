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
        payment.captured
        payment.authorized
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

      def resolve_org_and_subscription
        organization = nil
        subscription = nil
        event_id = @payload.dig("id").to_s

        # Path 1: Direct subscription entity in payload (subscription.* events)
        sub_entity = @payload.dig("payload", "subscription", "entity")
        if sub_entity.present?
          rzp_sub_id  = sub_entity.fetch("id", nil)
          notes       = sub_entity.fetch("notes", {}) || {}
          org_id      = notes["organization_id"]

          subscription = Subscription.find_by(razorpay_subscription_id: rzp_sub_id) if rzp_sub_id.present?
          organization = subscription&.organization || (Organization.find_by(id: org_id) if org_id.present?)
          
          Rails.logger.info("[WebhookProcessor] Event #{event_id}: Found org via subscription entity (org_id=#{org_id})")
        end

        # Path 2: Subscription ID in payment entity (payment.* events tied to subscriptions)
        if organization.nil?
          payment_entity = @payload.dig("payload", "payment", "entity")
          if payment_entity.present?
            rzp_sub_id = payment_entity.fetch("subscription_id", nil)
            
            if rzp_sub_id.present?
              subscription = Subscription.find_by(razorpay_subscription_id: rzp_sub_id)
              organization = subscription&.organization
              Rails.logger.info("[WebhookProcessor] Event #{event_id}: Found org via payment.subscription_id (sub_id=#{rzp_sub_id})")
            end
          end
        end

        # Path 3: Query Razorpay API to find the subscription for this payment (last resort)
        if organization.nil?
          payment_entity = @payload.dig("payload", "payment", "entity")
          if payment_entity.present?
            payment_id = payment_entity.fetch("id", nil)
            
            if payment_id.present?
              organization, subscription = find_org_via_razorpay_api(payment_id, event_id)
            end
          end
        end

        [ organization, subscription ]
      end

      # Query Razorpay to find which subscription owns this payment
      def find_org_via_razorpay_api(payment_id, event_id)
        begin
          payment = ::Razorpay::Payment.fetch(payment_id)
          rzp_sub_id = payment.subscription_id
          
          if rzp_sub_id.blank?
            Rails.logger.warn("[WebhookProcessor] Event #{event_id}: Payment #{payment_id} has no subscription_id in Razorpay API")
            return [nil, nil]
          end

          subscription = Subscription.find_by(razorpay_subscription_id: rzp_sub_id)
          organization = subscription&.organization
          
          if organization.present?
            Rails.logger.info("[WebhookProcessor] Event #{event_id}: Found org via Razorpay API (payment=#{payment_id}, subscription=#{rzp_sub_id})")
          else
            Rails.logger.warn("[WebhookProcessor] Event #{event_id}: Razorpay shows subscription=#{rzp_sub_id} but not found in DB")
          end
          
          [organization, subscription]
        rescue ::Razorpay::Error => e
          Rails.logger.error("[WebhookProcessor] Event #{event_id}: Razorpay API error fetching payment #{payment_id}: #{e.message}")
          [nil, nil]
        end
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
        "payment.failed"         => EventHandlers::PaymentFailed,
        "payment.captured"       => EventHandlers::PaymentCaptured,  # Invoice payment received
        "payment.authorized"     => EventHandlers::PaymentCaptured   # Pre-authorized payment
      }.freeze
    end
  end
end
