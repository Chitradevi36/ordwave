class AuthMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM', 'noreply@ordwave.com')

  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code

    mail(
      to: user.email,
      subject: "Your OrdWave login code: #{otp_code}"
    )
  end
end
