# frozen_string_literal: true

module Accounting
  module Sync
    # Retries a failed AccountingSyncRecord by re-enqueueing its processing job.
    #
    # Retry rules:
    #   - Record must be in a retryable status (failed).
    #   - Attempts must be below max_attempts.
    #   - A cooloff window is honoured based on priority to prevent hammering.
    #     (see COOLOFF_SECONDS_BY_PRIORITY)
    #   - If no attempts remain, the record is permanently abandoned.
    class RetrySyncRecordService
      # Minimum seconds since last_attempted_at before a record is eligible.
      # These are intentionally conservative for Phase 1.
      COOLOFF_SECONDS_BY_PRIORITY = {
        "high"   => 30,
        "medium" => 120,
        "low"    => 600
      }.freeze

      RETRYABLE_STATUSES = %w[failed retrying].freeze

      # @param sync_record [AccountingSyncRecord]
      def initialize(sync_record)
        @sync_record = sync_record
      end

      # @return [Symbol] :enqueued, :exhausted, :not_eligible, :skipped_cooloff
      def call
        unless retryable?
          Rails.logger.debug(
            "[RetrySyncRecordService] sync_record##{@sync_record.id} not retryable " \
            "(status=#{@sync_record.status}, attempts=#{@sync_record.attempts}/#{@sync_record.max_attempts})"
          )
          return :not_eligible
        end

        if no_attempts_remaining?
          abandon!
          return :exhausted
        end

        unless cooloff_elapsed?
          return :skipped_cooloff
        end

        enqueue!
        :enqueued
      rescue => e
        Rails.logger.error("[RetrySyncRecordService] #{e.class}: #{e.message}")
        :not_eligible
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      def retryable?
        RETRYABLE_STATUSES.include?(@sync_record.status.to_s)
      end

      def no_attempts_remaining?
        @sync_record.attempts >= @sync_record.max_attempts
      end

      def cooloff_elapsed?
        last = @sync_record.last_attempted_at
        return true if last.nil?

        cooloff = COOLOFF_SECONDS_BY_PRIORITY.fetch(
          @sync_record.priority.to_s,
          COOLOFF_SECONDS_BY_PRIORITY["medium"]
        )

        (Time.current - last) >= cooloff
      end

      def enqueue!
        # Mark as retrying so the sweeper does not pick it up again immediately.
        @sync_record.update_columns(
          status:           "retrying",
          last_attempted_at: Time.current
        )

        Accounting::ProcessSyncRecordJob.perform_later(@sync_record.id)

        Rails.logger.info(
          "[RetrySyncRecordService] sync_record##{@sync_record.id} re-enqueued " \
          "(attempt #{@sync_record.attempts + 1}/#{@sync_record.max_attempts})"
        )
      end

      def abandon!
        @sync_record.update_columns(
          status:        "failed",
          error_message: "#{@sync_record.error_message} [ABANDONED: max retries #{@sync_record.max_attempts} exhausted]"
        )

        Rails.logger.warn(
          "[RetrySyncRecordService] sync_record##{@sync_record.id} permanently abandoned " \
          "after #{@sync_record.max_attempts} attempts"
        )
      end
    end
  end
end
