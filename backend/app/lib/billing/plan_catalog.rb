# app/lib/billing/plan_catalog.rb
#
# Single source of truth for plan definitions, Razorpay plan IDs, and
# pricing.  The PlanLimits service delegates to this for plan data.
#
# Plans
#   free     — ₹0 / permanent free tier
#   starter  — ₹1,499 / month
#   pro      — ₹3,999 / month
#
module Billing
  module PlanCatalog
    PLANS = %w[free starter pro].freeze

    # Plan metadata used for display and checkout
    CATALOG = {
      "free" => {
        display_name:       "Free",
        price_paise:        0,          # paise (₹0)
        price_monthly_inr:  0,
        razorpay_plan_id:   nil,        # no subscription needed
        billing_period:     nil,
        trial_days:         0,
        description:        "Get started at no cost. Perfect for solo operators.",
        highlight:          false
      },
      "starter" => {
        display_name:       "Starter",
        price_paise:        149_900,    # ₹1,499
        price_monthly_inr:  1_499,
        razorpay_plan_id:   ENV.fetch("RAZORPAY_PLAN_ID_STARTER_MONTHLY", nil),
        billing_period:     "monthly",
        trial_days:         0,
        description:        "For small teams ready to scale operations.",
        highlight:          true
      },
      "pro" => {
        display_name:       "Pro",
        price_paise:        399_900,    # ₹3,999
        price_monthly_inr:  3_999,
        razorpay_plan_id:   ENV.fetch("RAZORPAY_PLAN_ID_PRO_MONTHLY", nil),
        billing_period:     "monthly",
        trial_days:         0,
        description:        "Unlimited power for growing distribution businesses.",
        highlight:          false
      }
    }.freeze

    # ── Accessors ─────────────────────────────────────────────────────────────

    def self.for(plan_name)
      CATALOG.fetch(plan_name.to_s) do
        raise ArgumentError, "Unknown plan: #{plan_name}. Valid plans: #{PLANS.join(', ')}"
      end
    end

    def self.free?(plan_name)
      plan_name.to_s == "free"
    end

    def self.paid?(plan_name)
      !free?(plan_name) && PLANS.include?(plan_name.to_s)
    end

    def self.valid?(plan_name)
      PLANS.include?(plan_name.to_s)
    end

    def self.razorpay_plan_id_for(plan_name)
      for(plan_name)[:razorpay_plan_id]
    end

    def self.all_for_display
      PLANS.map { |p| { plan: p }.merge(CATALOG[p]) }
    end
  end
end
