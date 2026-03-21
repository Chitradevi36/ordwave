# frozen_string_literal: true

class DunningMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.pro')

  # Day 1: Friendly reminder — assume customer forgot
  def friendly_reminder(invoice)
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @days_overdue = (Date.current - invoice.due_date).to_i

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "Friendly Reminder: Payment Due — Invoice #{@invoice.invoice_number}"
    )
  end

  # Day 5: Urgent notice — payment is overdue
  def urgent_notice(invoice)
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @days_overdue = (Date.current - invoice.due_date).to_i

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "⚠️ Urgent: Invoice #{@invoice.invoice_number} Is Overdue"
    )
  end

  # Day 10: Final notice — account suspension pending
  def final_notice(invoice)
    @invoice = invoice
    @organization = invoice.organization
    @customer = invoice.customer
    @days_overdue = (Date.current - invoice.due_date).to_i
    @suspension_date = (Date.current + 1.day).strftime('%b %d, %Y')

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "❌ Final Notice: Account Suspension Pending"
    )
  end

  # Account has been suspended due to non-payment
  def account_suspended(invoice, organization, customer)
    @invoice = invoice
    @organization = organization
    @customer = customer
    @days_overdue = (Date.current - invoice.due_date).to_i

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "🔒 Your Account Has Been Suspended"
    )
  end
end
