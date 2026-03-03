module Api
  module V1
    class SessionsController < ActionController::API
      def create
        user = User.find_by(email: params[:email])
        if user&.authenticate(params[:password])
          token = generate_token(user)
          render json: { token: token, user: user_payload(user) }
        else
          render json: { error: 'Invalid credentials' }, status: :unauthorized
        end
      end

      def destroy
        render json: { message: 'Logged out' }
      end

      def refresh
        render json: { message: 'Refresh not implemented' }, status: :not_implemented
      end

      private

      def generate_token(user)
        payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
        JWT.encode(payload, jwt_secret, 'HS256')
      end

      def jwt_secret
        ENV.fetch('JWT_SECRET', Rails.application.secret_key_base)
      end

      def user_payload(user)
        { id: user.id, email: user.email, first_name: user.first_name, last_name: user.last_name }
      end
    end
  end
end
