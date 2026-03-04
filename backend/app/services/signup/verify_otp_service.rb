module Signup
  class VerifyOtpService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(email:, otp_code:)
      @email    = email.to_s.downcase.strip
      @otp_code = otp_code.to_s
    end

    def call
      pending = PendingRegistration.active.find_by(email: @email)

      unless pending
        return Result.new(
          success?: false,
          pending_registration: nil,
          errors: ['No pending registration found or session expired']
        )
      end

      if pending.verify_otp(@otp_code)
        pending.advance_to!('verify_otp')
        Result.new(success?: true, pending_registration: pending, errors: [])
      else
        error_msg = if pending.otp_expired?
                      'OTP has expired. Please request a new one.'
                    elsif pending.otp_attempts >= PendingRegistration::MAX_OTP_ATTEMPTS
                      'Too many failed attempts. Please start over.'
                    else
                      'Invalid OTP code'
                    end
        Result.new(success?: false, pending_registration: pending, errors: [error_msg])
      end
    end
  end
end
