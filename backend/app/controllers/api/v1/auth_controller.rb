module Api
  module V1
    class AuthController < ActionController::API
      def login
        # Support credentials sent either at top-level or nested under `auth`.
        auth = params[:auth] || {}
        email = params[:email] || auth[:email] || auth['email']
        phone = params[:phone] || auth[:phone] || auth['phone']
        password = params[:password] || auth[:password] || auth['password']

        unless (email.present? || phone.present?) && password.present?
          return render json: { errors: ['Email/phone and password are required'] }, status: :bad_request
        end

        Rails.logger.debug("Auth#login params class=#{params.class} auth class=#{auth.class} email=#{email.inspect} phone=#{phone.inspect}")

        begin
          # Find user by email or phone
          if email.present?
            user = User.active.find_by(email: email)
          elsif phone.present?
            # Normalize phone for lookup (remove non-digits)
            normalized_phone = phone.gsub(/\D/, '')
            user = User.active.find_by(phone: normalized_phone)
          end
        rescue StandardError => e
          Rails.logger.error("Auth#login user lookup error: #{e.class}: #{e.message}")
          Rails.logger.error(params.to_unsafe_h.inspect) rescue nil
          return render json: { errors: ['Invalid credentials'] }, status: :unauthorized
        end

        begin
          unless user&.valid_password?(password)
            return render json: { errors: ['Invalid credentials'] }, status: :unauthorized
          end
        rescue StandardError => e
          Rails.logger.error("Auth#login error validating password: #{e.class}: #{e.message} -- params: ")
          Rails.logger.error(params.to_unsafe_h.slice(:email, :phone, :auth)) rescue nil
          return render json: { errors: ['Invalid credentials'] }, status: :unauthorized
        end

        # Generate JWT
        token = generate_jwt(user)
        
        # Update sign-in tracking
        user.update_tracked_fields!(request)

        render json: {
          data: {
            token: token,
            user:  serialize_user(user)
          }
        }, status: :ok
      end

      def logout
        # JWT is stateless; add to denylist if needed
        token = extract_token
        if token
          decoded = JWT.decode(token, jwt_secret, true, algorithm: 'HS256').first
          JwtDenylist.create!(jti: decoded['jti'], exp: Time.at(decoded['exp']))
        end

        head :no_content
      rescue JWT::DecodeError
        head :no_content
      end

      def request_otp
        # Request OTP for email or phone number login
        identifier = params[:identifier]
        
        unless identifier.present?
          return render json: { errors: ['Email or phone number required'] }, status: :bad_request
        end

        result = Auth::RequestOtpService.new(identifier: identifier).call

        if result.success?
          render json: {
            data: {
              request_id: result.otp_request.request_id,
              identifier_type: result.otp_request.identifier_type.to_s,
              message: 'OTP code sent to your email'
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def verify_otp
        # Verify OTP and login user
        identifier = params[:identifier]
        code = params[:code]
        request_id = params[:request_id]

        unless identifier.present? && code.present? && request_id.present?
          return render json: { errors: ['Identifier, code, and request_id are required'] }, status: :bad_request
        end

        result = Auth::VerifyOtpService.new(
          identifier: identifier,
          code: code,
          request_id: request_id
        ).call

        if result.success?
          render json: {
            data: {
              token: result.token,
              user: result.user
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unauthorized
        end
      end

      def google_login
        # Receive Google ID token from frontend
        # Verify token and authenticate/create user
        id_token = params[:id_token] || params.dig(:auth, :id_token)
        
        unless id_token.present?
          return render json: { errors: ['Google ID token required'] }, status: :bad_request
        end

        begin
          # Verify Google token and extract user data
          oauth_data = GoogleOauth::TokenVerifyService.call(id_token: id_token)
          
          # Find or link user by OAuth credentials
          user = User.find_or_create_from_oauth(
            provider: 'google',
            uid: oauth_data[:sub],
            email: oauth_data[:email],
            name: oauth_data[:name]
          )

          unless user
            return render json: { 
              errors: ['User not found. Please ask an administrator to add you to the system.'],
              hint: 'oauth_user_not_found'
            }, status: :unauthorized
          end

          unless user.active? && !user.deleted?
            return render json: { errors: ['User account is inactive'] }, status: :forbidden
          end

          # Generate JWT
          token = generate_jwt(user)
          
          # Update sign-in tracking
          user.update_tracked_fields!(request)

          render json: {
            data: {
              token: token,
              user: serialize_user(user)
            }
          }, status: :ok

        rescue GoogleOauth::TokenInvalidError => e
          Rails.logger.warn("Google OAuth login failed: #{e.message}")
          render json: { errors: ['Invalid Google token'] }, status: :unauthorized
        rescue StandardError => e
          Rails.logger.error("Google OAuth login error: #{e.class} #{e.message}")
          render json: { errors: ['Authentication failed'] }, status: :internal_server_error
        end
      end

      def refresh
        token = extract_token
        unless token
          return render json: { errors: ['Authorization token required'] }, status: :unauthorized
        end

        # Decode without verifying expiry so we can re-issue for recently-expired tokens
        decoded = JWT.decode(token, jwt_secret, true, algorithm: 'HS256', verify_expiration: false).first

        # Reject if denylisted
        if decoded['jti'] && JwtDenylist.exists?(jti: decoded['jti'])
          return render json: { errors: ['Token has been revoked'] }, status: :unauthorized
        end

        # Enforce a 7-day re-issue window (token must have expired within last 7 days)
        exp = decoded['exp'].to_i
        if exp < 7.days.ago.to_i
          return render json: { errors: ['Token too old to refresh — please log in again'] }, status: :unauthorized
        end

        user = User.active.find_by(id: decoded['sub'])
        unless user
          return render json: { errors: ['User not found'] }, status: :unauthorized
        end

        # Denylist the old token and issue a fresh one
        JwtDenylist.create!(jti: decoded['jti'], exp: Time.at(exp)) if decoded['jti']
        new_token = generate_jwt(user)

        render json: {
          data: {
            token: new_token,
            user:  serialize_user(user)
          }
        }, status: :ok
      rescue JWT::DecodeError
        render json: { errors: ['Invalid token'] }, status: :unauthorized
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

      def extract_token
        request.headers['Authorization']&.split(' ')&.last
      end

      def jwt_secret
        ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
      end

      def serialize_user(user)
        data = {
          id:                   user.id,
          email:                user.email,
          first_name:           user.first_name,
          last_name:            user.last_name,
          full_name:            user.full_name,
          phone:                user.phone,
          organization_id:      user.current_organization_id,
          current_organization_id: user.current_organization_id
        }

        # Attach membership info for current organization if present
        if defined?(user.memberships) && user.respond_to?(:memberships)
          membership = user.memberships.active.find_by(organization_id: user.current_organization_id)
          if membership
            data[:membership] = {
              id: membership.id,
              role: { id: membership.role_id, name: membership.role&.name },
              branch: { id: membership.branch_id, name: membership.branch&.name },
              status: membership.status
            }
          end
        end

        data
      end
    end
  end
end
