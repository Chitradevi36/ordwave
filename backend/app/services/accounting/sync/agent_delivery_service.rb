# frozen_string_literal: true

module Accounting
  module Sync
    # Handles sync record state transitions for agent-based delivery.
    #
    # Called by AgentController when agent reports success or failure.
    class AgentDeliveryService
      attr_reader :sync_record

      def initialize(sync_record)
        @sync_record = sync_record
      end

      # Mark sync record as successfully delivered to Tally
      def mark_delivered
        @sync_record.update!(
          status: "success",
          completed_at: Time.current,
          response_body: "Delivered via agent at #{Time.current.iso8601}"
        )

        Rails.logger.info(
          "[AgentDeliveryService] sync_record##{@sync_record.id} marked as delivered"
        )

        true
      rescue => e
        Rails.logger.error(
          "[AgentDeliveryService] Failed to mark sync_record##{@sync_record.id} as delivered: #{e.message}"
        )
        raise
      end

      # Mark sync record as failed and handle retry logic
      # @param error_message [String] the error message from Tally/agent
      def mark_failed(error_message)
        max_retries = AccountingSyncRecord::MAX_RETRIES[@sync_record.priority] || 3

        if @sync_record.attempt_count >= max_retries
          # Exhausted retries - mark as permanently failed
          @sync_record.update!(
            status: "failed",
            error_message: error_message,
            failed_at: Time.current
          )

          Rails.logger.warn(
            "[AgentDeliveryService] sync_record##{@sync_record.id} permanently failed after " \
            "#{@sync_record.attempt_count} attempts: #{error_message}"
          )
        else
          # Still have retries remaining - mark as retrying
          @sync_record.update!(
            status: "retrying",
            error_message: error_message,
            last_attempted_at: Time.current,
            attempt_count: @sync_record.attempt_count + 1
          )

          Rails.logger.info(
            "[AgentDeliveryService] sync_record##{@sync_record.id} marked for retry " \
            "(attempt #{@sync_record.attempt_count}/#{max_retries}): #{error_message}"
          )
        end

        true
      rescue => e
        Rails.logger.error(
          "[AgentDeliveryService] Failed to mark sync_record##{@sync_record.id} as failed: #{e.message}"
        )
        raise
      end
    end
  end
end
