# app/services/billing/razorpay/event_handlers/subscription_cancelled.rb
#
# Handles `subscription.cancelled` — set status to cancelled, compute ends_at.
#
module Billing
  module Razorpay
    module EventHandlers
      class SubscriptionCancelled
        def initialize(organization:, subscription:, payload:)
          @organization = organization
          @subscription = subscription
          @payload      = payload
        end

        def call
          return unless @subscription

          sub_data = @payload.dig("payload", "subscription", "entity") || {}
          ends_at  = sub_data["end_at"] ? Time.at(sub_data["end_at"]) : @subscription.current_period_end

          ActiveRecord::Base.transaction do
            @subscription.cancel!(at: Time.current)
            @subscription.update!(ends_at: ends_at) if ends_at
            # Keep billing_status as "active" until ends_at (access through period end)
            @organization.update!(billing_status: "cancelled")
          end

          notify_cancellation(ends_at)
        end

        private

        def notify_cancellation(ends_at)
          owner = @organization.users.joins(:memberships)
                               .where(memberships: { role: "owner" }).first
          return unless owner

          body = "Your #{@subscription.plan.capitalize} subscription has been cancelled."
          body += " You'll have access until #{ends_at.strftime('%d %b %Y')}." if ends_at

          Notifications::CreateService.new(
            user:         owner,
            organization: @organization,
            kind:         "billing_cancelled",
            title:        "Subscription cancelled",
            body:         body,
            metadata:     { plan: @subscription.plan, ends_at: ends_at&.iso8601 }
          ).call
        rescue StandardError => e
          Rails.logger.warn("[BillingNotification] Cancellation notification error: #{e.message}")
        end
      end
    end
  end
end
