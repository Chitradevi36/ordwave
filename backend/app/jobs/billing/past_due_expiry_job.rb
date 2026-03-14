# app/jobs/billing/past_due_expiry_job.rb
#
# Scheduled daily — expires subscriptions that have been in `past_due` beyond
# their grace period. Downgrades the organization to the free plan.
#
# Sidekiq Cron schedule (add to config/initializers/sidekiq_cron.rb or sidekiq.yml):
#   "Billing Past Due Expiry":
#     cron: "0 1 * * *"
#     class: "Billing::PastDueExpiryJob"
#
module Billing
  class PastDueExpiryJob
    include Sidekiq::Job

    sidekiq_options queue: :billing, retry: 2

    def perform
      # Find past_due subscriptions whose grace period has ended
      expired_subs = Subscription.where(status: "past_due")
                                 .where("ends_at < ?", Time.current)

      expired_subs.find_each do |sub|
        ActiveRecord::Base.transaction do
          org = sub.organization

          # Mark subscription as expired
          sub.update!(status: "expired")

          # Downgrade organization to free plan
          org.update!(plan: "free", billing_status: "inactive")

          # Record internal event
          BillingEvent.record_internal!(
            organization: org,
            subscription: sub,
            event_type:   "internal.trial_expired",
            payload:      {
              previous_plan:  sub.plan,
              downgraded_at:  Time.current.iso8601,
              reason:         "grace_period_expired"
            }
          )
        end

        notify_downgrade(sub)
      rescue StandardError => e
        Rails.logger.error("[PastDueExpiryJob] Error for subscription #{sub.id}: #{e.message}")
      end
    end

    private

    def notify_downgrade(sub)
      owner = sub.organization.users.joins(:memberships)
                 .where(memberships: { role: "owner" }).first
      return unless owner

      Notifications::CreateService.new(
        user:         owner,
        organization: sub.organization,
        kind:         "billing_downgraded",
        title:        "Account downgraded to Free plan",
        body:         "Your #{sub.plan.capitalize} subscription has ended due to payment failure. " \
                      "Your account has been moved to the Free plan. " \
                      "Upgrade anytime to restore full access.",
        metadata:     { previous_plan: sub.plan, current_plan: "free" }
      ).call
    rescue StandardError => e
      Rails.logger.warn("[PastDueExpiryJob] Downgrade notification error: #{e.message}")
    end
  end
end
