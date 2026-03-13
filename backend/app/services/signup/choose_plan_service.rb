module Signup
  class ChoosePlanService
    Result = Struct.new(:success?, :user, :token, :requires_payment, :subscription_short_url, :errors, keyword_init: true)

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
          success?: false, user: nil, token: nil,
          requires_payment: false, subscription_short_url: nil,
          errors: ['No pending registration found or session expired']
        )
      end

      unless pending.current_step == 'set_password'
        return Result.new(
          success?: false, user: nil, token: nil,
          requires_payment: false, subscription_short_url: nil,
          errors: ['Please complete previous steps first']
        )
      end

      unless @plan.in?(User::PLANS)
        return Result.new(
          success?: false, user: nil, token: nil,
          requires_payment: false, subscription_short_url: nil,
          errors: ["Invalid plan. Choose from: #{User::PLANS.join(', ')}"]
        )
      end

      user  = nil
      token = nil

      ActiveRecord::Base.transaction do
        user = User.create!(
          email:      @email,
          password:   pending.data['password'],
          first_name: @first_name,
          last_name:  @last_name,
          phone:      @phone,
          plan:       @plan,
          active:     true
        )

        # Free plan → complete registration immediately
        if Billing::PlanCatalog.free?(@plan)
          pending.advance_to!('choose_plan')
          pending.mark_completed!
        else
          # Paid plan → advance to billing_pending (checkout in progress)
          pending.advance_to!('billing_pending')
          # NOTE: subscription is created lazily when user hits POST /billing/checkout
          # (the user may not have an organization yet at this point)
        end

        token = generate_jwt(user)
      end

      requires_payment = Billing::PlanCatalog.paid?(@plan)

      Result.new(
        success?:               true,
        user:                   user,
        token:                  token,
        requires_payment:       requires_payment,
        subscription_short_url: nil,   # populated later via POST /billing/checkout
        errors:                 []
      )
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        success?: false, user: nil, token: nil,
        requires_payment: false, subscription_short_url: nil,
        errors: e.record.errors.full_messages
      )
    rescue ActiveRecord::RecordNotFound => e
      Result.new(
        success?: false, user: nil, token: nil,
        requires_payment: false, subscription_short_url: nil,
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
