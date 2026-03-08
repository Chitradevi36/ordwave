# frozen_string_literal: true

module Accounting
  # Periodic sweep job that retries eligible failed AccountingSyncRecords.
  #
  # Intended to run on a schedule (e.g. every 5 minutes via Sidekiq-Cron
  # or Whenever).  Example sidekiq-cron entry:
  #
  #   "accounting_retry_failed_syncs":
  #     cron: "*/5 * * * *"
  #     class: "Accounting::RetryFailedSyncsJob"
  #     queue: accounting_retry
  #
  # Safety limits:
  #   BATCH_LIMIT   — max records per single sweep (prevents thundering herd).
  #   Cooloff logic — delegated to RetrySyncRecordService.
  class RetryFailedSyncsJob < ApplicationJob
    queue_as :accounting_retry

    # Maximum records to retry per sweep.
    BATCH_LIMIT = 100

    # Only retry records last attempted more than MIN_AGE_SECONDS ago to avoid
    # picking up records that are still within their cooloff window at the DB
    # query level before the service checks.
    MIN_AGE_SECONDS = 30

    def perform
      records = eligible_records

      Rails.logger.info(
        "[RetryFailedSyncsJob] sweeping #{records.size} eligible failed sync records"
      )

      enqueued = 0
      records.each do |record|
        result = Accounting::Sync::RetrySyncRecordService.new(record).call
        enqueued += 1 if result == :enqueued
      end

      Rails.logger.info(
        "[RetryFailedSyncsJob] sweep complete — #{enqueued}/#{records.size} enqueued"
      )
    end

    # -----------------------------------------------------------------------
    private
    # -----------------------------------------------------------------------

    def eligible_records
      AccountingSyncRecord
        .where(status: %w[failed retrying])
        .where("attempts < max_attempts")
        .where("last_attempted_at IS NULL OR last_attempted_at < ?", MIN_AGE_SECONDS.seconds.ago)
        .order(priority_sql, last_attempted_at: :asc)
        .limit(BATCH_LIMIT)
    end

    # Highest-priority records first.  Maps string priority to sort integer.
    def priority_sql
      Arel.sql(
        "CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 WHEN 'low' THEN 2 ELSE 3 END"
      )
    end
  end
end
