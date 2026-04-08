class AuthMailer < ApplicationMailer
  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code

    mail(
      to: @user.email,
      subject: "Your OrdWave login code: #{@otp_code}"
    )
  end
end
