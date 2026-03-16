class PaymentMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.com')

  def alt_payment_link(invoice:, customer:, payment_link_url:)
    @invoice = invoice
    @customer = customer
    @payment_link_url = payment_link_url
    @organization = invoice.organization

    mail(
      to: customer.email,
      subject: "Invoice #{invoice.invoice_number} - Payment Reminder"
    )
  end
end
