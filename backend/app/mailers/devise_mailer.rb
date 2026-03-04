class DeviseMailer < Devise::Mailer
  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    subject = I18n.t('devise.mailer.reset_password_instructions.subject')

    # Generate reset password URL for the frontend
    reset_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/reset-password?token=#{token}"
    @reset_url = reset_url

    mail(
      subject: subject,
      to: record.email,
      from: ENV.fetch('MAILER_FROM', 'noreply@omnidist.com')
    )
  end
end
