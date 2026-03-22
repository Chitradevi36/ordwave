class SignupMailer < ApplicationMailer
  def send_otp(pending_registration)
    @otp = pending_registration.otp_code
    @email = pending_registration.email
    @expires_in = '10 minutes'

    mail(
      to: @email,
      subject: "Your OrdWave verification code: #{@otp}"
    )
  end
end
