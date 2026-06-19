module Signup
  class VerifyOtpService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(identifier:, otp_code:)
      @raw_identifier = identifier.to_s.strip
      @email = normalize_email(@raw_identifier)
      @phone = normalize_phone(@raw_identifier)
      @otp_code = otp_code.to_s
    end

    def call
      pending = if @email.present?
                  PendingRegistration.active.find_by(email: @email)
                elsif @phone.present?
                  PendingRegistration.active.find_by(phone: @phone)
                end

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

    private

    def normalize_email(value)
      val = value.to_s.strip
      return nil unless val.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
      val.downcase
    end

    def normalize_phone(value)
      digits = value.to_s.gsub(/\D/, '')
      return nil unless digits.match?(/\A[6-9]\d{9}\z/)
      digits
    end
  end
end
