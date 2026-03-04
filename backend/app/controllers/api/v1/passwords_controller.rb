module Api
  module V1
    class PasswordsController < ActionController::API
      def forgot
        user = User.find_by(email: params[:email])

        if user
          user.send_reset_password_instructions
          render json: {
            data: { message: 'Password reset instructions sent to your email' }
          }, status: :ok
        else
          # Don't reveal whether user exists
          render json: {
            data: { message: 'If that email exists, password reset instructions will be sent' }
          }, status: :ok
        end
      end

      def validate_token
        user = User.with_reset_password_token(params[:reset_token])

        if user && user.reset_password_period_valid?
          render json: {
            data: {
              valid: true,
              email: user.email
            }
          }, status: :ok
        else
          render json: {
            errors: ['Invalid or expired reset token']
          }, status: :unprocessable_entity
        end
      end

      def reset
        user = User.with_reset_password_token(params[:reset_token])

        unless user && user.reset_password_period_valid?
          return render json: {
            errors: ['Invalid or expired reset token']
          }, status: :unprocessable_entity
        end

        if params[:password].blank? || params[:password].length < 8
          return render json: {
            errors: ['Password must be at least 8 characters']
          }, status: :unprocessable_entity
        end

        if params[:password] != params[:password_confirmation]
          return render json: {
            errors: ['Password confirmation does not match']
          }, status: :unprocessable_entity
        end

        if user.reset_password(params[:password], params[:password_confirmation])
          render json: {
            data: { message: 'Password has been reset successfully' }
          }, status: :ok
        else
          render json: {
            errors: user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
