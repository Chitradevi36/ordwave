module Auth
  class VerifyOtpService
    Result = Struct.new(:success?, :user, :token, :errors, keyword_init: true)

    def initialize(identifier:, code:, request_id:)
      @identifier = identifier.to_s.strip
      @code = code.to_s.strip
      @request_id = request_id.to_s.strip
    end

    def call
      # Find the OTP request
      otp_request = OtpRequest.find_by(request_id: @request_id)
      
      unless otp_request
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['OTP request not found or expired. Please request a new code.']
        )
      end

      # Check if OTP is still valid
      unless otp_request.valid_otp?
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['OTP code has expired or too many attempts. Please request a new code.']
        )
      end

      # Verify OTP code
      unless otp_request.verify_otp(@code)
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['Invalid OTP code. Please try again.']
        )
      end

      # Find user by identifier
      user = otp_request.find_user
      unless user&.active? && !user.deleted?
        return Result.new(
          success?: false,
          user: nil,
          token: nil,
          errors: ['Account not found or inactive.']
        )
      end

      # Generate JWT token
      token = generate_jwt(user)
      
      # Mark OTP as verified (before we generate token)
      otp_request.update!(verified: true, verified_at: Time.current)

      Result.new(success?: true, user: serialize_user(user), token: token, errors: [])
    rescue StandardError => e
      Rails.logger.error("OTP verification error: #{e.class} #{e.message}")
      Result.new(
        success?: false,
        user: nil,
        token: nil,
        errors: ['Verification failed. Please try again.']
      )
    end

    private

    def generate_jwt(user)
      jti = SecureRandom.uuid
      expiry_seconds = Devise::JWT.config.expiration_time || 4.hours.to_i
      payload = {
        sub:   user.id,
        aud:   'user',
        email: user.email,
        jti:   jti,
        exp:   expiry_seconds.seconds.from_now.to_i,
        iat:   Time.current.to_i
      }
      JWT.encode(payload, jwt_secret, 'HS256')
    end

    def jwt_secret
      ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
    end

    def serialize_user(user)
      {
        id:                   user.id,
        email:                user.email,
        first_name:           user.first_name,
        last_name:            user.last_name,
        full_name:            user.full_name,
        phone:                user.phone,
        organization_id:      user.current_organization_id,
        current_organization_id: user.current_organization_id
      }
    end
  end
end
