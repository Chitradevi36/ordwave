# frozen_string_literal: true

class DunningEnforcementJob
  include Sidekiq::Job
  sidekiq_options queue: 'operations', retry: 2

  # Feature 9: Enforces dunning-based account restrictions
  # Scheduled daily at 9 AM (after DunningSequenceJob runs at 8 AM)
  #
  # Enforcement timeline:
  #   Day 5 overdue:  Flag account for review (soft block - orders require approval)
  #   Day 10 overdue: Suspend account (hard block - no new orders)
  #   Day 15 overdue: Alert operations manager for manual intervention
  #
  def perform
    Organization.active.find_each do |organization|
      process_organization(organization)
    end
  rescue StandardError => error
    log_error("DunningEnforcementJob failed", error)
    raise error # Retry
  end

  private

  def process_organization(organization)
    # Find customers with overdue invoices
    overdue_customers = organization.customers
                                   .joins(sales_invoices: :payments)
                                   .distinct
                                   .where(sales_invoices: { status: %w[issued partially_paid] })
                                   .where('sales_invoices.due_date < ?', Date.current)

    overdue_customers.find_each do |customer|
      days_overdue = (Date.current - customer.sales_invoices.map(&:due_date).min).to_i
      apply_enforcement(customer, days_overdue, organization)
    end
  rescue StandardError => error
    log_error("Error processing organization #{organization.id}", error)
  end

  def apply_enforcement(customer, days_overdue, organization)
    case days_overdue
    when 5..9
      # Day 5-9: Soft block - flag for review, don't prevent orders yet
      apply_day_5_enforcement(customer, organization)
    when 10..14
      # Day 10-14: Hard block - prevent new orders
      apply_day_10_enforcement(customer, organization)
    else
      # Day 15+: Alert manager
      apply_day_15_enforcement(customer, organization) if days_overdue >= 15
    end
  rescue StandardError => error
    log_error("Error applying enforcement for customer #{customer.id}", error)
  end

  def apply_day_5_enforcement(customer, organization)
    # Day 5: Set credit_block_rule to soft_block if not already applied
    return if customer.credit_block_rule == 'soft_block' ||
              customer.credit_block_rule == 'hard_block' ||
              customer.dunning_suspended_at.present?

    customer.update(credit_block_rule: 'soft_block')

    # Notify finance team
    notify_finance_team(customer, organization, 'day_5',
      "Customer #{customer.name} (#{customer.code}) has overdue invoices for 5 days. " \
      "New orders now require manual approval.")

    log_info("Day 5 enforcement applied to customer #{customer.id}: soft block enabled")
  rescue StandardError => error
    log_error("Error applying Day 5 enforcement for customer #{customer.id}", error)
  end

  def apply_day_10_enforcement(customer, organization)
    # Day 10: Set hard block if not already suspended
    return if customer.dunning_suspended_at.present?

    customer.update(
      credit_block_rule: 'hard_block',
      dunning_suspended_at: Time.current,
      dunning_suspension_reason: 'day_10'
    )

    # Notify finance team
    notify_finance_team(customer, organization, 'day_10',
      "URGENT: Customer #{customer.name} (#{customer.code}) account is now SUSPENDED. " \
      "No new orders allowed. Manual intervention required.")

    log_info("Day 10 enforcement applied to customer #{customer.id}: account suspended")
  rescue StandardError => error
    log_error("Error applying Day 10 enforcement for customer #{customer.id}", error)
  end

  def apply_day_15_enforcement(customer, organization)
    # Day 15: Alert operations manager for manual action
    return if customer.notification_data&.dig('day_15_alert_sent').present?

    # Find operations managers
    managers = User.joins(:memberships)
                   .where(memberships: { organization_id: organization.id, active: true })
                   .joins(memberships: :role)
                   .where(roles: { name: %w[manager admin] })
                   .distinct

    managers.each do |manager|
      Notification.create(
        organization: organization,
        user: manager,
        title: 'Critical: Highly Overdue Account - Manual Action Needed',
        body: "Customer #{customer.name} (#{customer.code}) has been overdue for 15+ days. " \
              "Account is suspended. Consider contacting customer or initiating collection process.",
        notification_type: 'dunning_escalation_15day',
        deep_link_url: "/customers/#{customer.id}",
        severity: 'critical'
      )
    end

    # Send SMS to first manager if available
    if TwilioClient.enabled? && managers.any?
      manager_phone = managers.first.phone
      if manager_phone.present?
        TwilioClient.send_sms(
          phone_number: manager_phone,
          message: "URGENT: #{customer.name} (#{customer.code}) overdue 15+ days. Account suspended. " \
                   "Manual collection action recommended. #{organization.name}"
        ) rescue nil
      end
    end

    # Track that we sent the alert
    notification_data = customer.notification_data || {}
    notification_data['day_15_alert_sent'] = Time.current.iso8601
    customer.update_column(:notification_data, notification_data)

    log_info("Day 15 enforcement applied to customer #{customer.id}: manager alert sent")
  rescue StandardError => error
    log_error("Error applying Day 15 enforcement for customer #{customer.id}", error)
  end

  def notify_finance_team(customer, organization, enforcement_day, message)
    # Find finance team members
    finance_users = User.joins(:memberships)
                        .where(memberships: { organization_id: organization.id, active: true })
                        .joins(memberships: :role)
                        .where(roles: { name: %w[finance admin] })
                        .distinct

    return unless finance_users.any?

    finance_users.each do |user|
      Notification.create(
        organization: organization,
        user: user,
        title: "Dunning Enforcement - #{enforcement_day.humanize}",
        body: message,
        notification_type: "dunning_enforced_#{enforcement_day}",
        deep_link_url: "/customers/#{customer.id}",
        severity: enforcement_day == 'day_10' ? 'high' : 'medium'
      )
    end
  rescue StandardError => error
    log_warn("Failed to notify finance team for customer #{customer.id}: #{error.message}")
  end

  def log_info(message)
    Rails.logger.info({
      job: 'DunningEnforcementJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_warn(message)
    Rails.logger.warn({
      job: 'DunningEnforcementJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'DunningEnforcementJob',
      message: message,
      error: error.message,
      backtrace: error.backtrace[0..4]
    }.to_json)
  end
end
