# app/services/billing/razorpay/event_handlers/subscription_charged.rb
#
# Handles `subscription.charged` — the most important event.
# A charge means the customer paid, so we activate their subscription and org.
#
module Billing
  module Razorpay
    module EventHandlers
      class SubscriptionCharged
        def initialize(organization:, subscription:, payload:)
          @organization = organization
          @subscription = subscription
          @payload      = payload
        end

        def call
          sub_data     = @payload.dig("payload", "subscription", "entity") || {}
          payment_data = @payload.dig("payload", "payment", "entity") || {}

          period_start = sub_data["current_start"] ? Time.at(sub_data["current_start"]) : Time.current
          period_end   = sub_data["current_end"]   ? Time.at(sub_data["current_end"])   : 1.month.from_now
          rzp_sub_id   = sub_data["id"] || @subscription&.razorpay_subscription_id

          ActiveRecord::Base.transaction do
            @subscription.activate!(
              period_start:            period_start,
              period_end:              period_end,
              razorpay_subscription_id: rzp_sub_id
            )

            @organization.activate_billing!(plan_name: @subscription.plan)
          end

          # Notify the organization owner
          notify_activation
        end

        private

        def notify_activation
          owner = @organization.users.joins(:memberships)
                               .where(memberships: { role: "owner" }).first
          return unless owner

          Notifications::CreateService.new(
            user:         owner,
            organization: @organization,
            kind:         "billing_activated",
            title:        "Subscription activated",
            body:         "Your #{@subscription.plan.capitalize} plan is now active. Welcome aboard!",
            metadata:     { plan: @subscription.plan }
          ).call
        rescue StandardError => e
          Rails.logger.warn("[BillingNotification] Failed to send activation notification: #{e.message}")
        end
      end
    end
  end
end
