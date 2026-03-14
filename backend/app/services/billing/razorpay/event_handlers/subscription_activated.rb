# app/services/billing/razorpay/event_handlers/subscription_activated.rb
#
# Handles `subscription.activated` — Razorpay fires this when a subscription
# transitions from `created` → `active` (first charge may not have occurred yet
# for some plan types). We update period dates but only activate the org
# upon `subscription.charged`.
#
module Billing
  module Razorpay
    module EventHandlers
      class SubscriptionActivated
        def initialize(organization:, subscription:, payload:)
          @organization = organization
          @subscription = subscription
          @payload      = payload
        end

        def call
          return unless @subscription

          sub_data = @payload.dig("payload", "subscription", "entity") || {}
          period_start = sub_data["current_start"] ? Time.at(sub_data["current_start"]) : Time.current
          period_end   = sub_data["current_end"]   ? Time.at(sub_data["current_end"])   : 1.month.from_now

          @subscription.update!(
            current_period_start:    period_start,
            current_period_end:      period_end,
            razorpay_subscription_id: sub_data["id"] || @subscription.razorpay_subscription_id
          )
        end
      end
    end
  end
end
