class AccountingAgentHeartbeatJob < ApplicationJob
  # LOW-30: Sets accounting_agent.status to 'offline' when no heartbeat has been
  # received for more than OFFLINE_THRESHOLD_MINUTES.  Prevents the dashboard
  # from showing stale 'online' agents that have actually disconnected.
  # Scheduled every 5 minutes via sidekiq-cron (see config/sidekiq.yml).
  OFFLINE_THRESHOLD_MINUTES = 10

  queue_as :default
  sidekiq_options retry: 1, dead: false

  def perform
    cutoff = OFFLINE_THRESHOLD_MINUTES.minutes.ago

    stale_agents = AccountingAgent
                     .where(status: %w[online syncing])
                     .where('last_heartbeat_at < ? OR last_heartbeat_at IS NULL', cutoff)

    stale_agents.find_each do |agent|
      agent.update_columns(status: 'offline')
      Rails.logger.info("[AccountingAgentHeartbeatJob] Agent #{agent.agent_id} marked offline — " \
                        "last heartbeat: #{agent.last_heartbeat_at&.iso8601 || 'never'}")
    ensure
      nil
    end
  end
end
