# app/jobs/billing/past_due_reminder_job.rb
#
# Scheduled daily — sends payment reminder to organizations that are in
# `past_due` billing status.
#
# Sidekiq Cron schedule (add to config/initializers/sidekiq_cron.rb or sidekiq.yml):
#   "Billing Past Due Reminder":
#     cron: "0 10 * * *"
#     class: "Billing::PastDueReminderJob"
#
module Billing
  class PastDueReminderJob
    include Sidekiq::Job

    sidekiq_options queue: :billing, retry: 2

    def perform
      Organization.where(billing_status: "past_due").find_each do |org|
        sub = org.subscriptions.where(status: "past_due").order(updated_at: :desc).first
        next unless sub

        # Skip if grace period has ended — handled by PastDueExpiryJob
        next if sub.ends_at && sub.ends_at < Time.current

        owner = org.users.joins(:memberships)
                   .where(memberships: { role: "owner" }).first
        next unless owner

        Notifications::CreateService.new(
          user:         owner,
          organization: org,
          kind:         "billing_past_due_reminder",
          title:        "Action required: Payment failed",
          body:         "Your #{sub.plan.capitalize} plan payment has failed. " \
                        "Please update your payment method to avoid service interruption. " \
                        "Grace period ends: #{sub.ends_at&.strftime('%d %b %Y') || 'soon'}.",
          metadata:     { plan: sub.plan, ends_at: sub.ends_at&.iso8601 }
        ).call
      rescue StandardError => e
        Rails.logger.error("[PastDueReminderJob] Error for org #{org.id}: #{e.message}")
      end
    end
  end
end
