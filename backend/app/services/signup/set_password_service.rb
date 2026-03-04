module Signup
  class SetPasswordService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(email:, password:, password_confirmation:)
      @email                 = email.to_s.downcase.strip
      @password              = password
      @password_confirmation = password_confirmation
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

      unless pending.current_step.in?(%w[verify_otp set_password])
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Please verify your email first']
        )
      end

      # Validate password
      if @password.blank? || @password.length < 8
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Password must be at least 8 characters']
        )
      end

      if @password != @password_confirmation
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Password confirmation does not match']
        )
      end

      pending.store_data!(password: @password)
      pending.advance_to!('set_password')

      Result.new(success?: true, pending_registration: pending, errors: [])
    end
  end
end
