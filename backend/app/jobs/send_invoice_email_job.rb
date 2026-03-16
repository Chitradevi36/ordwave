# frozen_string_literal: true

# Sends invoice notification email to customer asynchronously.
#
# Triggered by:
#   - Invoice::GenerateFromDeliveryService after invoice creation
#   - SalesInvoicesController create action
#
# Retries up to 5 times on transient failures (network, etc)
# Discards silently on permanent failures (invalid email, etc)
#
class SendInvoiceEmailJob < ApplicationJob
  queue_as :emails

  # Retry on transient errors (network, timeout, etc)
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # Discard silently on permanent failures
  discard_on Net::SMTPSyntaxError           # Invalid recipient
  discard_on Net::SMTPServerBusy            # Server overload
  discard_on_record_not_found

  # @param invoice_id [Integer] SalesInvoice id
  # @param recipient_email [String] Email address to send to (optional, uses invoice.customer.email)
  def perform(invoice_id, recipient_email = nil)
    invoice = SalesInvoice.find(invoice_id)

    # Skip if feature disabled
    unless FEATURES.invoice_email_notifications_enabled?(invoice.organization)
      Rails.logger.info("[SendInvoiceEmailJob] Email notifications disabled for org #{invoice.organization_id}")
      return
    end

    # Skip if customer has no email
    customer_email = recipient_email || invoice.customer&.email
    unless customer_email.present?
      Rails.logger.warn("[SendInvoiceEmailJob] No email address for invoice #{invoice_id}")
      return
    end

    started_at = Time.current

    begin
      InvoiceMailer.notify_issued(invoice).deliver_later

      duration = ((Time.current - started_at) * 1000).round
      Rails.logger.info("[SendInvoiceEmailJob] Email enqueued for invoice #{invoice_id} to #{customer_email} (#{duration}ms)")
    rescue StandardError => e
      Rails.logger.error("[SendInvoiceEmailJob] Failed to send email for invoice #{invoice_id}: #{e.class} — #{e.message}")
      raise
    end
  end
end
