module Signup
  class InitiateService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(email:)
      @email = email.to_s.downcase.strip
    end

    def call
      # Check if user already exists
      if User.exists?(email: @email)
        return Result.new(
          success?: false,
          pending_registration: nil,
          errors: ['Email is already registered. Please login instead.']
        )
      end

      # Find or create pending registration
      pending = PendingRegistration.find_or_initialize_by(email: @email)
      pending.current_step = 'initiate'
      pending.completed = false
      pending.expires_at = 24.hours.from_now

      # Generate and "send" OTP (in real app, send via email/SMS)
      pending.generate_otp!

      SignupMailer.send_otp(pending).deliver_later

      Result.new(success?: true, pending_registration: pending, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, pending_registration: nil, errors: e.record.errors.full_messages)
    end
  end
end
