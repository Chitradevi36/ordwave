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
        # TODO: Implement refresh token logic
        render json: { errors: ['Refresh not yet implemented'] }, status: :not_implemented
      end

      private

      def generate_jwt(user)
        jti = SecureRandom.uuid
        payload = {
          sub:   user.id,
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
