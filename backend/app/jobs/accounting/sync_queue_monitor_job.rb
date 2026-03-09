# frozen_string_literal: true

module Accounting
  # Background job to monitor sync queue health and agent connectivity.
  #
  # Responsibilities:
  #   1. Reset "processing" records that have been stuck for >10 minutes (agent crash/disconnect)
  #   2. Mark integrations as disconnected if agent hasn't sent heartbeat in >2 minutes
  #   3. Log queue stats for monitoring
  #
  # Schedule: Every 5 minutes via Sidekiq cron or Rails task
  class SyncQueueMonitorJob < ApplicationJob
    queue_as :accounting

    def perform
      reset_stale_processing_records
      check_agent_connectivity
      log_queue_stats
    end

    private

    # Reset sync records stuck in "processing" state
    # These are records the agent claimed but never acknowledged
    def reset_stale_processing_records
      stale_threshold = 10.minutes.ago

      stale_records = AccountingSyncRecord
                       .where(status: "processing")
                       .where("processing_started_at < ?", stale_threshold)

      count = stale_records.count
      return if count.zero?

      Rails.logger.warn(
        "[SyncQueueMonitorJob] Resetting #{count} stale processing records " \
        "(processing_started_at < #{stale_threshold})"
      )

      stale_records.update_all(
        status: "pending",
        processing_started_at: nil,
        error_message: "Reset due to agent timeout"
      )

      Rails.logger.info("[SyncQueueMonitorJob] Reset #{count} stale records to pending")
    end

    # Check agent connectivity and mark integrations as error if agent is offline
    def check_agent_connectivity
      AccountingIntegration.sync_mode_realtime_agent.find_each do |integration|
        agent = integration.accounting_agents.first

        next unless agent

        if agent.online?
          # Agent is healthy - ensure integration is marked as connected
          if integration.status_error? && integration.error_message&.include?("Agent offline")
            integration.update!(status: "connected", error_message: nil)
            Rails.logger.info(
              "[SyncQueueMonitorJob] integration##{integration.id} reconnected (agent online)"
            )
          end
        else
          # Agent is offline - mark integration as error
          unless integration.status_error?
            integration.update!(
              status: "error",
              error_message: "Agent offline since #{agent.last_heartbeat_at || 'never'}"
            )
            Rails.logger.warn(
              "[SyncQueueMonitorJob] integration##{integration.id} marked as error (agent offline)"
            )
          end
        end
      end
    end

    # Log queue statistics for monitoring/alerting
    def log_queue_stats
      stats = {
        pending: AccountingSyncRecord.status_pending.count,
        processing: AccountingSyncRecord.status_processing.count,
        retrying: AccountingSyncRecord.status_retrying.count,
        failed: AccountingSyncRecord.status_failed.count,
        success_last_24h: AccountingSyncRecord.status_success.where("completed_at > ?", 24.hours.ago).count,
        agents_online: AccountingAgent.online.count,
        agents_total: AccountingAgent.count
      }

      Rails.logger.info("[SyncQueueMonitorJob] Queue stats: #{stats.to_json}")

      # Optional: Send to monitoring service (Datadog, New Relic, etc.)
      # StatsD.gauge('accounting.sync_queue.pending', stats[:pending])
      # StatsD.gauge('accounting.sync_queue.processing', stats[:processing])
      # StatsD.gauge('accounting.agents.online', stats[:agents_online])
    end
  end
end
