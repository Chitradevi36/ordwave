class RejectPaymentWindowJob
  include Sidekiq::Job
  sidekiq_options retry: 3, dead: true

  # This job is scheduled to run 1 hour after an auto-posted payment
  # It handles cleanup of the rejection window and logs any unclosed window situations

  def perform(payment_id)
    payment = Payment.find_by(id: payment_id)
    return unless payment.present?
    return unless payment.auto_posted?

    if payment.rejection_window_expired?
      # Window has expired - mark as finalized
      handle_window_expiration(payment)
    else
      # Window still open - reschedule this job
      time_remaining = payment.rejection_window_expires_at - Time.current
      if time_remaining > 0
        RejectPaymentWindowJob.perform_at(
          payment.rejection_window_expires_at,
          payment_id
        )
      end
    end
  rescue => e
    Rails.logger.error("RejectPaymentWindowJob failed for payment #{payment_id}: #{e.message}")
    raise
  end

  private

  def handle_window_expiration(payment)
    return if payment.reversed?  # Already rejected

    # Payment window has expired without rejection
    # This means the finance team accepted the auto-post (implicitly)
    payment.update!(
      rejection_window_expires_at: nil
    )

    # Create audit trail for window closure
    AutoPostAudit.create!(
      payment: payment,
      bank_transaction: payment.bank_transaction,
      auto_posted: true,
      action: 'auto_posted',
      actor: User.system_user,
      timestamp: Time.current,
      audit_notes: "Rejection window expired - auto-post finalized"
    )

    # Notify finance of finalization (optional)
    notify_window_closed(payment)
  end

  def notify_window_closed(payment)
    invoice = payment.sales_invoices.first
    return unless invoice.present?

    # Optional: Send notification to finance that window has closed
    Rails.logger.info(
      "Payment window closed: Payment #{payment.id} for Invoice #{invoice.invoice_number}"
    )
  end
end
