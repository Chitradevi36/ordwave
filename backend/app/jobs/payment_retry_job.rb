class PaymentRetryJob
  include Sidekiq::Job
  sidekiq_options queue: 'billing', retry: 3

  # Scheduled daily at 1 AM via config/sidekiq.yml
  def perform
    process_pending_retries
    process_scheduled_retries
  rescue => error
    log_error("PaymentRetryJob failed", error)
    raise error # Sidekiq will retry
  end

  private

  def process_pending_retries
    # Find failed payments that haven't been scheduled yet but are old enough to retry
    # Rule: First retry after 24 hours, second after 48 hours, third after 72 hours
    
    Payment.where(external_payment_status: 'failed', retry_status: 'pending')
           .where('created_at < ?', 24.hours.ago)
           .where('retry_count < 3')
           .find_each do |payment|
      schedule_retry(payment)
    end
  rescue => error
    log_error("Error processing pending retries", error)
  end

  def process_scheduled_retries
    # Find payments scheduled for retry that are now ready
    Payment.where(retry_status: 'scheduled')
           .where('next_retry_at <= ?', Time.current)
           .where('retry_count < 3')
           .find_each do |payment|
      attempt_retry(payment)
    end
  rescue => error
    log_error("Error processing scheduled retries", error)
  end

  def schedule_retry(payment)
    # Determine when to schedule the next retry based on how many we've done
    next_retry_delay = case payment.retry_count
                       when 0 then 24.hours  # First retry after 24 hours
                       when 1 then 48.hours  # Second retry after 48 hours
                       when 2 then 72.hours  # Third retry after 72 hours
                       else return           # No more retries
                       end

    next_retry_at = Time.current + next_retry_delay

    payment.update(
      retry_status: 'scheduled',
      next_retry_at: next_retry_at
    )

    # Notify customer about scheduled retry
    send_retry_notification(payment)
  rescue => error
    log_error("Error scheduling retry for payment #{payment.id}", error)
  end

  def attempt_retry(payment)
    invoice = payment.invoice
    organization = invoice.organization
    customer = invoice.customer

    return unless invoice && organization && customer

    begin
      # Attempt to process the payment via Razorpay
      response = retry_razorpay_payment(payment)

      if response&.dig('status') == 'captured'
        # Retry succeeded!
        payment.update(
          external_payment_status: 'captured',
          external_confirmed_at: Time.current,
          retry_status: 'completed',
          last_retry_at: Time.current
        )

        # Trigger invoice payment cascade logic
        payment.sync_to_invoices!

        # Send success notification
        PaymentRetryMailer.payment_retry_successful(payment, organization, customer, invoice).deliver_later

        log_info("Payment #{payment.id} retry successful on attempt #{payment.retry_count + 1}")
      else
        # Retry failed, schedule next one or mark as exhausted
        handle_retry_failure(payment, response)
      end
    rescue => error
      log_error("Error attempting retry for payment #{payment.id}", error)
      handle_retry_failure(payment, error.message)
    end
  rescue => error
    log_error("Error processing retry for payment #{payment.id}", error)
  end

  def handle_retry_failure(payment, response)
    invoice = payment.invoice
    organization = invoice.organization
    customer = invoice.customer

    # Increment retry count
    payment.increment!(:retry_count)

    if payment.retry_count >= 3
      # All retries exhausted - create alternative payment link
      payment.update(
        retry_status: 'abandoned',
        last_retry_at: Time.current
      )

      # Instead of giving up, generate an alternative payment link for customer
      generate_alternative_payment_link(payment, invoice, organization, customer)

      # Create audit log
      AuditLog.create(
        organization_id: organization.id,
        entity_type: 'Payment',
        entity_id: payment.id,
        action: 'payment_retry_exhausted',
        details: {
          invoice_id: invoice.id,
          total_attempts: payment.retry_count,
          last_error: response.is_a?(String) ? response : response.to_s
        }
      ) if organization

      log_info("Payment #{payment.id} retries exhausted (3 attempts failed)")
    else
      # Schedule next retry
      schedule_retry(payment)
    end
  end

  def send_retry_notification(payment)
    invoice = payment.invoice
    organization = invoice.organization
    customer = invoice.customer

    return unless invoice && organization && customer

    PaymentRetryMailer.payment_failed_notification(payment, organization, customer, invoice).deliver_later
  rescue => error
    log_error("Error sending retry notification for payment #{payment.id}", error)
  end

  def generate_alternative_payment_link(payment, invoice, organization, customer)
    # Generate a new Razorpay payment link for customer to retry
    # Much higher chance of payment recovery via fresh link than just notifying
    
    return unless organization && customer && invoice

    result = Payments::GenerateAltPaymentLinkService.call(
      payment: payment,
      customer: customer,
      invoice: invoice,
      organization: organization
    )

    if result.success?
      log_info(
        "Alternative payment link generated for payment #{payment.id}: #{result.payment_link_url}"
      )
    else
      log_error(
        "Failed to generate alternative payment link: #{result.errors.join(', ')}", 
        StandardError.new(result.errors.first)
      )
    end
  rescue => error
    log_error("Error generating alternative payment link for payment #{payment.id}", error)
  end

  def retry_razorpay_payment(payment)
    # Call Razorpay to retry the payment
    # This assumes the payment method is stored in Razorpay
    
    external_id = payment.external_payment_id
    return nil unless external_id

    begin
      client = Razorpay::Client.new(
        key: ENV['RAZORPAY_KEY_ID'],
        secret: ENV['RAZORPAY_KEY_SECRET']
      )

      # Attempt to capture the payment if it's in authorized state
      # Or re-attempt if it's failed
      # For now, this is a placeholder - actual implementation depends on Razorpay API
      
      # In production, you might:
      # 1. Fire a new payment link and request customer re-authorization
      # 2. Use Razorpay's token-based recurring payment API if available
      # 3. Store customer card details securely and retry

      # Placeholder response indicating the payment should be retried via new link
      {
        'status' => 'pending_customer_action',
        'message' => 'Customer needs to re-authorize payment'
      }
    rescue => error
      log_error("Error calling Razorpay retry API for payment #{payment.id}", error)
      nil
    end
  end

  def log_info(message)
    Rails.logger.info({
      job: 'PaymentRetryJob',
      message: message,
      timestamp: Time.current
    }.to_json)
  end

  def log_error(message, error)
    Rails.logger.error({
      job: 'PaymentRetryJob',
      message: message,
      error: error.message,
      backtrace: error.backtrace[0..4]
    }.to_json)
  end
end
