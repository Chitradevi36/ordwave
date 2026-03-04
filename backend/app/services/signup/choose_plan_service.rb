module Signup
  class ChoosePlanService
    Result = Struct.new(:success?, :user, :token, :errors, keyword_init: true)

    def initialize(email:, plan:, first_name:, last_name:, phone: nil)
      @email      = email.to_s.downcase.strip
      @plan       = plan.to_s.downcase
      @first_name = first_name
      @last_name  = last_name
      @phone      = phone
    end

    def call
      pending = PendingRegistration.active.find_by(email: @email)

      unless pending
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['No pending registration found or session expired']
        )
      end

      unless pending.current_step == 'set_password'
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['Please complete previous steps first']
        )
      end

      unless @plan.in?(User::PLANS)
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ["Invalid plan. Choose from: #{User::PLANS.join(', ')}"]
        )
      end

      user = nil
      token = nil

      ActiveRecord::Base.transaction do
        # Create user with the selected plan
        # Organization, branch, and membership will be created during onboarding
        user = User.create!(
          email:      @email,
          password:   pending.data['password'],
          first_name: @first_name,
          last_name:  @last_name,
          phone:      @phone,
          plan:       @plan,
          active:     true
        )

        # Mark pending registration as completed
        pending.advance_to!('choose_plan')
        pending.mark_completed!

        # Generate JWT token
        token = generate_jwt(user)
      end

      Result.new(
        success?: true,
        user: user,
        token: token,
        errors: []
      )
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        success?: false,
        user: nil,
        token: nil,
        errors: e.record.errors.full_messages
      )
    rescue ActiveRecord::RecordNotFound => e
      Result.new(
        success?: false,
        user: nil,
        token: nil,
        errors: [e.message]
      )
    end

    private

    def generate_jwt(user)
      payload = {
        sub:   user.id,
        email: user.email,
        exp:   24.hours.from_now.to_i,
        iat:   Time.current.to_i
      }
      JWT.encode(payload, jwt_secret, 'HS256')
    end

    def jwt_secret
      ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
    end
  end
end
