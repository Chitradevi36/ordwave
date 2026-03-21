# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.pro')

  # Sends invoice notification email to customer
  # Called by: SendInvoiceEmailJob
  def notify_issued(invoice)
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @order = invoice.sales_order

    # Ensure customer has email
    return unless @customer&.email.present?

    subject = "Invoice #{@invoice.invoice_number} from #{@organization.name}"

    mail(
      to:      @customer.email,
      subject: subject,
      headers: {
        'X-Invoice-ID'      => @invoice.id,
        'X-Organization-ID' => @organization.id,
        'List-Unsubscribe'  => "<mailto:#{ENV['MAILER_FROM_ADDRESS']}?subject=unsubscribe>"
      }
    )
  end

  # Sends payment reminder for overdue invoices
  # Called by: DunningSequenceJob (in 1B.1)
  def payment_reminder(invoice, day_type = 'day_1')
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @day_type = day_type
    @days_overdue = (Date.current - invoice.due_date).to_i

    return unless @customer&.email.present?

    subject_map = {
      'day_1'  => "Friendly Reminder: Invoice #{@invoice.invoice_number} Due",
      'day_5'  => "Urgent: Invoice #{@invoice.invoice_number} Is Overdue",
      'day_10' => "Final Notice: Account Suspension Pending"
    }

    subject = subject_map[@day_type] || "Payment Due: Invoice #{@invoice.invoice_number}"

    mail(
      to:      @customer.email,
      subject: subject
    )
  end

  # Sends payment failure notification
  # Called by: PaymentRetryJob (in 1B.2)
  def payment_failed(invoice, failure_reason = nil)
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @failure_reason = failure_reason || 'Payment processing failed'

    return unless @customer&.email.present?

    subject = "Payment Failed: Invoice #{@invoice.invoice_number} — Action Required"

    mail(
      to:      @customer.email,
      subject: subject
    )
  end
end
