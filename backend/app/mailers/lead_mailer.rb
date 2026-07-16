class LeadMailer < ApplicationMailer
  def demo_request(payload)
    @payload = payload.with_indifferent_access

    recipient = ENV.fetch('LEAD_INBOX_EMAIL', 'team.ordwave@gmail.com')

    mail(
      to: recipient,
      subject: "[OrdWave] New Demo Request - #{@payload[:company]}"
    )
  end
end
