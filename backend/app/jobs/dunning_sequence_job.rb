class DunningSequenceJob
  include Sidekiq::Job
  sidekiq_options queue: 'default', retry: 3

  # Scheduled daily at 8 AM via config/sidekiq.yml
  def perform
    Organization.where("dunning_config->>'enabled' = ?", 'true').find_each do |organization|
      process_organization(organization)
    end
  rescue => error
    log_error("DunningSequenceJob failed", error)
    raise error # Sidekiq will retry
  end

  private

  def process_organization(organization)
    organization.sales_invoices
                .where(status: ['issued', 'partially_paid'])
                .where('due_date < ?', Date.current)
                .find_each do |invoice|
      process_invoice(invoice, organization)
    end
  rescue => error
    log_error("Error processing organization #{organization.id}", error)
  end

  def process_invoice(invoice, organization)
    return if should_skip_invoice?(invoice)

    days_overdue = (Date.current - invoice.due_date).to_i
    dunning_step = determine_dunning_step(days_overdue)

    return unless dunning_step
    return if already_sent_today?(invoice, dunning_step)

    dunning_config = organization.dunning_config
    return unless dunning_config.dig(dunning_step, 'enabled')

    # Check if exceeded monthly reminder limit
    return if exceeded_monthly_limit?(invoice, dunning_step)

    # Check quiet hours (don't send between 22:00 and 08:00)
    return if within_quiet_hours?(organization)

    # Send the appropriate email
    send_dunning_email(invoice, dunning_step, organization)

    # Record the attempt
    record_attempt(invoice, dunning_step)

    # Handle suspension action if configured
    handle_suspension_action(invoice, dunning_step, organization) if dunning_step == 'day_10'
  rescue => error
    log_error("Error processing invoice #{invoice.id}", error)
  end

  def should_skip_invoice?(invoice)
    # Skip if no customer email
    return true if invoice.customer&.email.blank?

    # Skip if already has payment pending (don't dunning while payment in progress)
    return true if invoice.payments.any? { |p| p.external_payment_status == 'authorized' }

    false
  end

  def determine_dunning_step(days_overdue)
    case days_overdue
    when 1..4
      'day_1'
    when 5..9
      'day_5'
    when 10..Float::INFINITY
      'day_10'
    else
      nil
    end
  end

  def already_sent_today?(invoice, dunning_step)
    attempts = invoice.dunning_attempts || {}
    
    attempts.values.any? do |attempt|
      attempt.is_a?(Hash) &&
        attempt['type'] == dunning_step &&
        attempt['sent_at'].present? &&
        Time.parse(attempt['sent_at']).date == Date.current
    end
  rescue => error
    log_error("Error checking sent status for invoice #{invoice.id}", error)
    true # Skip if we can't determine status
  end

  def exceeded_monthly_limit?(invoice, dunning_step)
    max_reminders = invoice.organization.dunning_config&.dig('max_reminders_per_month')&.to_i || 3
    
    attempts = invoice.dunning_attempts || {}
    this_month = attempts.values.select do |attempt|
      next false unless attempt.is_a?(Hash)
      next false unless attempt['sent_at'].present?

      sent_time = Time.parse(attempt['sent_at'])
      sent_time.year == Date.current.year && sent_time.month == Date.current.month
    end

    this_month.count >= max_reminders
  rescue => error
    log_error("Error checking monthly limit for invoice #{invoice.id}", error)
    false
  end

  def within_quiet_hours?(organization)
    quiet_start = organization.dunning_config&.dig('quiet_hours_start')&.to_i || 22
    quiet_end = organization.dunning_config&.dig('quiet_hours_end')&.to_i || 8
    
    current_hour = Time.current.hour

    if quiet_start < quiet_end
      # Normal case: e.g., 9 AM to 5 PM
      current_hour >= quiet_start && current_hour < quiet_end
    else
      # Wrap-around case: e.g., 10 PM to 8 AM
      current_hour >= quiet_start || current_hour < quiet_end
    end
  rescue => error
    log_error("Error checking quiet hours", error)
    false # Send email if we can't determine quiet hours
  end

  def send_dunning_email(invoice, dunning_step, organization)
    customer = invoice.customer
    days_overdue = (Date.current - invoice.due_date).to_i

    case dunning_step
    when 'day_1'
      DunningMailer.friendly_reminder(invoice, organization, customer, days_overdue).deliver_later
    when 'day_5'
      DunningMailer.urgent_notice(invoice, organization, customer, days_overdue).deliver_later
    when 'day_10'
      DunningMailer.final_notice(invoice, organization, customer, days_overdue).deliver_later
    end
  rescue => error
    log_error("Error sending dunning email for invoice #{invoice.id}, step #{dunning_step}", error)
    raise error # Let Sidekiq retry the entire job
  end

  def record_attempt(invoice, dunning_step)
    attempts = invoice.dunning_attempts || {}
    
    # Create a unique key for this attempt
    attempt_key = "#{dunning_step}_#{Date.current.to_s}"
    
    attempts[attempt_key] = {
      'day' => (Date.current - invoice.due_date).to_i,
      'type' => dunning_step,
      'sent_at' => Time.current.iso8601,
      'customer_email' => invoice.customer.email,
      'invoice_amount' => invoice.total_amount
    }
    
    invoice.update_columns(dunning_attempts: attempts, updated_at: Time.current)
  rescue => error
    log_error("Error recording dunning attempt for invoice #{invoice.id}", error)
    # Don't raise - we sent the email, just couldn't record it
  end

  def handle_suspension_action(invoice, dunning_step, organization)
    action = organization.dunning_config&.dig('day_10', 'action')
    return unless action == 'suspend_account'

    # Suspend the customer account
    customer = invoice.customer
    return unless customer

    customer.update(account_status: 'suspended', account_suspended_at: Time.current)

    # Send suspension notification
    DunningMailer.account_suspended(invoice, organization, customer).deliver_later

    # Log the suspension event
    AuditLog.create(
      organization_id: organization.id,
      entity_type: 'Customer',
      entity_id: customer.id,
      action: 'account_suspended_due_to_dunning',
      details: {
        invoice_id: invoice.id,
        invoice_number: invoice.invoice_number,
        days_overdue: (Date.current - invoice.due_date).to_i,
        triggered_by: 'DunningSequenceJob'
      }
    )
  rescue => error
    log_error("Error handling suspension for invoice #{invoice.id}", error)
    # Don't raise - we already sent the final notice
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'DunningSequenceJob',
      message: message,
      error: error.message,
      backtrace: error.backtrace[0..4]
    }.to_json)
  end
end
