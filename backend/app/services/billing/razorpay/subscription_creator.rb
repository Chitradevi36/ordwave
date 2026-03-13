# app/services/billing/razorpay/subscription_creator.rb
#
# Creates a Razorpay subscription for an Organization and persists a local
# Subscription record in "pending" state.
#
# Returns a short_url that the frontend should redirect the customer to.
#
module Billing
  module Razorpay
    class SubscriptionCreator
      Result = Struct.new(:success?, :subscription, :short_url, :error, keyword_init: true)

      def initialize(organization:, plan:)
        @organization = organization
        @plan         = plan.to_s
      end

      def call
        # Validate plan
        unless Billing::PlanCatalog.paid?(@plan)
          return Result.new(success?: false, subscription: nil, short_url: nil,
                            error: "#{@plan} does not require a Razorpay subscription")
        end

        razorpay_plan_id = Billing::PlanCatalog.razorpay_plan_id_for(@plan)
        unless razorpay_plan_id.present?
          return Result.new(success?: false, subscription: nil, short_url: nil,
                            error: "RAZORPAY_PLAN_ID_#{@plan.upcase}_MONTHLY is not configured")
        end

        # Ensure customer exists in Razorpay
        customer_result = Billing::Razorpay::CustomerCreator.new(@organization).call
        unless customer_result.success?
          return Result.new(success?: false, subscription: nil, short_url: nil,
                            error: customer_result.error)
        end

        # Create Razorpay subscription
        rzp_subscription = ::Razorpay::Subscription.create(
          plan_id:            razorpay_plan_id,
          customer_id:        customer_result.customer_id,
          total_count:        120,              # 10 years — effectively unlimited
          quantity:           1,
          customer_notify:    1,
          notes: {
            organization_id:   @organization.id.to_s,
            organization_name: @organization.name,
            plan:              @plan
          },
          notify_info: {
            success_url: "#{ENV.fetch('APP_BASE_URL', 'https://app.orderlane.in')}/onboarding?billing=success",
            cancel_url:  "#{ENV.fetch('APP_BASE_URL', 'https://app.orderlane.in')}/onboarding?billing=cancelled"
          }
        )

        # Persist a local Subscription record in "pending" state
        subscription = @organization.subscriptions.create!(
          plan:                     @plan,
          status:                   "pending",
          razorpay_subscription_id: rzp_subscription.id,
          razorpay_plan_id:         razorpay_plan_id,
          metadata:                 { razorpay_short_url: rzp_subscription.short_url }
        )

        Result.new(
          success?:     true,
          subscription: subscription,
          short_url:    rzp_subscription.short_url,
          error:        nil
        )
      rescue ::Razorpay::Error => e
        Rails.logger.error("[Billing::SubscriptionCreator] Razorpay error: #{e.message}")
        Result.new(success?: false, subscription: nil, short_url: nil, error: e.message)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[Billing::SubscriptionCreator] DB error: #{e.message}")
        Result.new(success?: false, subscription: nil, short_url: nil, error: e.message)
      end
    end
  end
end
