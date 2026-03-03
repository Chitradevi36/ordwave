module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_user!
      rescue_from Pundit::NotAuthorizedError, with: :forbidden

      private

      def current_user
        @current_user ||= User.find_by(id: jwt_payload['user_id'])
      end

      def authenticate_user!
        render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
      end

      def jwt_payload
        token = request.headers['Authorization']&.split(' ')&.last
        return {} unless token
        JWT.decode(token, jwt_secret, true, algorithm: 'HS256').first
      rescue JWT::DecodeError
        {}
      end

      def jwt_secret
        ENV.fetch('JWT_SECRET', Rails.application.secret_key_base)
      end

      def forbidden
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
