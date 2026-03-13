# app/controllers/api/v1/billing_controller.rb
#
# Manages the billing subscription lifecycle for an organization.
#
# All actions require a valid JWT (authenticate_user!) and operate on
# current_organization (resolved by BaseController).
#
module Api
  module V1
    class BillingController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/billing/subscription
      # Returns the current subscription + plan summary + usage.
      def subscription
        sub = current_organization.current_subscription
        limits = PlanLimits.for(current_organization)

        render json: {
          data: {
            subscription:  sub ? serialize_subscription(sub) : nil,
            plan:          current_organization.plan,
            billing_status: current_organization.billing_status,
            plan_details:  Billing::PlanCatalog.for(current_organization.plan).slice(
                             :display_name, :price_monthly_inr, :description
                           ),
            usage_summary: limits.summary,
            all_plans:     Billing::PlanCatalog.all_for_display
          }
        }
      end

      # POST /api/v1/billing/checkout
      # Creates a Razorpay subscription for a plan and returns the short_url
      # for the hosted checkout page.
      #
      # Params:
      #   plan (string) — "starter" or "pro"
      def checkout
        plan = params[:plan].to_s.downcase

        unless Billing::PlanCatalog.paid?(plan)
          return render json: { errors: ["#{plan} does not require payment"] },
                        status: :unprocessable_entity
        end

        result = Billing::Razorpay::SubscriptionCreator.new(
          organization: current_organization,
          plan:         plan
        ).call

        if result.success?
          render json: {
            data: {
              subscription_id:    result.subscription.id,
              short_url:          result.short_url,
              plan:               plan,
              message:            "Redirecting to payment..."
            }
          }, status: :created
        else
          render json: { errors: [result.error] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/billing/cancel
      # Cancels the active subscription.  Requires org owner.
      def cancel
        unless current_user_is_org_owner?
          return render json: { errors: ["Only the account owner can cancel the subscription"] },
                        status: :forbidden
        end

        sub = current_organization.subscriptions.active.last

        unless sub
          return render json: { errors: ["No active subscription found"] },
                        status: :unprocessable_entity
        end

        # Cancel on Razorpay (at period end)
        begin
          ::Razorpay::Subscription.cancel(sub.razorpay_subscription_id, cancel_at_cycle_end: 1)
        rescue ::Razorpay::Error => e
          return render json: { errors: ["Razorpay error: #{e.message}"] },
                        status: :unprocessable_entity
        end

        sub.cancel!(at: Time.current)
        current_organization.update!(billing_status: "cancelled")

        BillingEvent.record_internal!(
          organization: current_organization,
          subscription: sub,
          event_type:   "internal.plan_changed",
          payload:      { action: "cancel", cancelled_by: current_user.id }
        )

        render json: {
          data: {
            message: "Subscription cancelled. Access continues until #{sub.ends_at&.strftime('%d %b %Y') || 'end of period'}.",
            ends_at: sub.ends_at&.iso8601
          }
        }
      end

      # GET /api/v1/billing/invoices
      # Returns a paginated list of billing events (payment history).
      def invoices
        events = current_organization.billing_events
                                     .where(event_type: %w[subscription.charged payment.captured payment.failed])
                                     .order(created_at: :desc)
                                     .limit(50)

        render json: {
          data: events.map { |e| serialize_billing_event(e) }
        }
      end

      private

      def current_user_is_org_owner?
        current_organization.memberships
                             .where(user: current_user, role: "owner")
                             .exists?
      end

      def serialize_subscription(sub)
        {
          id:                       sub.id,
          plan:                     sub.plan,
          status:                   sub.status,
          razorpay_subscription_id: sub.razorpay_subscription_id,
          current_period_start:     sub.current_period_start&.iso8601,
          current_period_end:       sub.current_period_end&.iso8601,
          cancelled_at:             sub.cancelled_at&.iso8601,
          ends_at:                  sub.ends_at&.iso8601,
          created_at:               sub.created_at.iso8601
        }
      end

      def serialize_billing_event(event)
        {
          id:         event.id,
          event_type: event.event_type,
          created_at: event.created_at.iso8601,
          amount:     event.payload.dig("payload", "payment", "entity", "amount"),
          currency:   event.payload.dig("payload", "payment", "entity", "currency") || "INR",
          status:     event.processed? ? "processed" : "pending"
        }
      end
    end
  end
end
