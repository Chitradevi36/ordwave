# app/services/billing/razorpay/event_handlers/payment_failed.rb
#
# Handles `payment.failed` — mark subscription past_due, notify owner.
#
module Billing
  module Razorpay
    module EventHandlers
      class PaymentFailed
        GRACE_PERIOD_DAYS = 7

        def initialize(organization:, subscription:, payload:)
          @organization = organization
          @subscription = subscription
          @payload      = payload
        end

        def call
          return unless @subscription

          ActiveRecord::Base.transaction do
            @subscription.mark_past_due!(grace_ends_at: GRACE_PERIOD_DAYS.days.from_now)
            @organization.update!(billing_status: "past_due")
          end

          notify_payment_failed
        end

        private

        def notify_payment_failed
          owner = @organization.users.joins(:memberships)
                               .where(memberships: { role: "owner" }).first
          return unless owner

          Notifications::CreateService.new(
            user:         owner,
            organization: @organization,
            kind:         "billing_payment_failed",
            title:        "Payment failed",
            body:         "We couldn't charge your card for the #{@subscription.plan.capitalize} plan. " \
                          "Please update your payment method within #{GRACE_PERIOD_DAYS} days to avoid service interruption.",
            metadata:     { plan: @subscription.plan, grace_ends_at: @subscription.ends_at&.iso8601 }
          ).call
        rescue StandardError => e
          Rails.logger.warn("[BillingNotification] PaymentFailed notification error: #{e.message}")
        end
      end
    end
  end
end
