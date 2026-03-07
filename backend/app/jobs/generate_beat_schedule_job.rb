# Generates upcoming visit slots from BeatSchedule records for a given
# organization and branch over a rolling date window (default: next 7 days).
#
# Runs as a nightly Sidekiq-Cron job or can be triggered manually.
#
# Usage:
#   GenerateBeatScheduleJob.perform_later(organization_id: 1, branch_id: 2)
#   GenerateBeatScheduleJob.perform_later(organization_id: 1, branch_id: 2,
#                                         from_date: "2026-03-10",
#                                         days_ahead: 14)
#
class GenerateBeatScheduleJob < ApplicationJob
  queue_as :low

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # @param organization_id [Integer]
  # @param branch_id       [Integer]
  # @param from_date       [String|nil]  ISO-8601; defaults to tomorrow
  # @param days_ahead      [Integer]     window to generate; default 7
  def perform(organization_id:, branch_id:, from_date: nil, days_ahead: 7)
    org    = Organization.find(organization_id)
    branch = Branch.find(branch_id)

    start_date = from_date ? Date.parse(from_date.to_s) : Date.tomorrow
    end_date   = start_date + days_ahead.days

    Current.organization = org

    schedules = BeatSchedule
                  .active
                  .where(organization: org, branch: branch)
                  .includes(:beat, :sales_rep, :beat_retailers)

    generated = 0
    skipped   = 0

    (start_date..end_date).each do |date|
      # Date#cwday: 1=Monday … 7=Sunday → convert to 0-indexed
      weekday = date.cwday - 1

      schedules.for_weekday(weekday).each do |schedule|
        # Idempotency: skip if a visit slot already exists for this date + schedule
        if VisitLog.exists?(beat_schedule: schedule, visited_on: date)
          skipped += 1
          next
        end

        schedule.beat_retailers.each do |beat_retailer|
          VisitLog.create!(
            organization:   org,
            branch:         branch,
            beat_schedule:  schedule,
            beat:           schedule.beat,
            sales_rep:      schedule.sales_rep,
            customer_id:    beat_retailer.customer_id,
            planned_date:   date,
            visited_on:     date,
            status:         "planned"
          )
          generated += 1
        end
      end
    end

    Rails.logger.info(
      "[GenerateBeatScheduleJob] org=#{organization_id} branch=#{branch_id} " \
      "window=#{start_date}..#{end_date} generated=#{generated} skipped=#{skipped}"
    )
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    Rails.logger.error("[GenerateBeatScheduleJob] Failed: #{e.message}")
    raise
  end
end
