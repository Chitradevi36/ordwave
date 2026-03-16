class DeliveryMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.com')

  def escalated_delivery_options(order, customer, organization)
    @order = order
    @customer = customer
    @organization = organization
    
    mail(
      to: customer.email,
      subject: "Your Delivery Failed - Choose an Option"
    )
  end

  def refund_initiated(order, customer, organization)
    @order = order
    @customer = customer
    @organization = organization
    @refund_amount = order.total_amount

    mail(
      to: customer.email,
      subject: "Refund Initiated - Order #{order.order_number}"
    )
  end
end
