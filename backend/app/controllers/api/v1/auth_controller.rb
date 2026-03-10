module Api
  module V1
    class AuthController < ActionController::API
      def login
        user = User.active.find_by(email: params[:email])

        unless user&.valid_password?(params[:password])
          return render json: { errors: ['Invalid email or password'] }, status: :unauthorized
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
        payload = {
          sub:   user.id,
          aud:   'user',
          email: user.email,
          jti:   jti,
          exp:   24.hours.from_now.to_i,
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
        {
          id:         user.id,
          email:      user.email,
          first_name: user.first_name,
          last_name:  user.last_name,
          full_name:  user.full_name,
          phone:      user.phone
        }
      end
    end
  end
end
