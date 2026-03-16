# frozen_string_literal: true

class PaymentRetryMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.pro')

  # Notify customer that their payment failed and provide retry option
  def payment_failed_notification(payment, organization, customer, invoice)
    @payment = payment
    @organization = organization
    @customer = customer
    @invoice = invoice
    @failed_reason = format_failure_reason(payment.failed_reason)
    @retry_number = payment.retry_count + 1

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "Payment Failed for Invoice #{@invoice.invoice_number} — Retry Options Available"
    )
  end

  # Notify that a retry attempt was made and succeeded
  def payment_retry_successful(payment, organization, customer, invoice)
    @payment = payment
    @organization = organization
    @customer = customer
    @invoice = invoice
    @retry_number = payment.retry_count

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "✅ Payment Successful for Invoice #{@invoice.invoice_number}"
    )
  end

  # Notify that retries have been exhausted
  def payment_retry_exhausted(payment, organization, customer, invoice)
    @payment = payment
    @organization = organization
    @customer = customer
    @invoice = invoice
    @failed_reason = format_failure_reason(payment.failed_reason)

    return unless @customer&.email.present?

    mail(
      to: @customer.email,
      subject: "⚠️ Payment Retry Failed for Invoice #{@invoice.invoice_number} — Manual Action Required"
    )
  end

  private

  def format_failure_reason(reason)
    case reason
    when 'insufficient_funds'
      'Your account has insufficient funds'
    when 'card_declined'
      'Your card was declined by the bank'
    when 'network_error'
      'A temporary network connection error occurred'
    when 'gateway_timeout'
      'The payment gateway did not respond in time'
    when 'invalid_credentials'
      'Invalid card credentials provided'
    when 'expired_card'
      'Your card has expired'
    when 'duplicate_transaction'
      'This transaction appears to be a duplicate'
    else
      "Payment processing error: #{reason}"
    end
  end
end
