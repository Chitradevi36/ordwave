class LeadMailer < ApplicationMailer
  def demo_request(payload)
    @payload = payload.with_indifferent_access

    recipient = ENV.fetch('LEAD_INBOX_EMAIL', 'support@ordwave.com')

    mail(
      to: recipient,
      subject: "Ordwave - Demo Request"
    )
  end
end
