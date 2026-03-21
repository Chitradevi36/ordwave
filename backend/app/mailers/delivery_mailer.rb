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

  # Feature 10: Delivery Failure Notification
  def delivery_failed_notification(order, customer, reschedule_date, organization)
    @order = order
    @customer = customer
    @organization = organization
    @reschedule_date = reschedule_date
    @formatted_date = reschedule_date.strftime('%B %d, %Y')

    mail(
      to: customer.email,
      subject: "Your Delivery on #{@formatted_date} - Order #{order.order_number}"
    )
  end
end
