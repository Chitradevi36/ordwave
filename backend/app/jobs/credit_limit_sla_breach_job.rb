class CreditLimitSlaBreachJob < ApplicationJob
  # HIGH-06: Stamps sla_breached_at on CreditLimitChangeRequests that have
  # exceeded their org's approval SLA but haven't been decided yet.
  # Scheduled every 30 minutes via config/sidekiq.yml.
  #
  # SLA windows are per CreditPolicy:
  #   approval_sla_hours_manager  — for manager-assigned requests
  #   approval_sla_hours_owner    — for owner-escalated requests
  # This job uses the more conservative (shorter) sla_hours_manager window
  # unless the request was already escalated past manager level, in which case
  # it uses sla_hours_owner.
  queue_as :default
  sidekiq_options retry: 1, dead: false

  def perform
    now = Time.current

    # Load all pending, un-breached requests that have an organization
    pending = CreditLimitChangeRequest
                .joins(credit_account: :organization)
                .where(status: 'pending', sla_breached_at: nil)
                .includes(credit_account: { organization: :credit_policy })

    pending.each do |request|
      policy = request.credit_account.organization.credit_policy
      next unless policy

      sla_hours = policy.approval_sla_hours_manager
      deadline  = request.created_at + sla_hours.hours

      next unless now > deadline

      request.update_columns(sla_breached_at: now)

      notify_owners_of_breach(request, sla_hours)
    rescue StandardError => e
      Rails.logger.warn("[CreditLimitSlaBreachJob] Failed to process request #{request.id}: #{e.message}")
    end
  end

  private

  def notify_owners_of_breach(request, sla_hours)
    org = request.credit_account.organization
    owners = User.joins(:memberships)
                 .where(memberships: { organization_id: org.id, deleted_at: nil, active: true })
                 .joins(memberships: :role)
                 .where(roles: { name: %w[owner admin] })
                 .distinct

    Notifications::CreateService.call(
      organization: org,
      recipients:   owners,
      actor:        nil,
      notifiable:   request,
      type:         'credit_limit_sla_breached',
      title:        "Credit limit change request SLA breached",
      body:         "Request ##{request.id} has exceeded the #{sla_hours}h approval SLA.",
      deep_link:    '/settings/credit',
      severity:     'high'
    )
  rescue StandardError => e
    Rails.logger.warn("[CreditLimitSlaBreachJob] Notification failed: #{e.message}")
  end
end
