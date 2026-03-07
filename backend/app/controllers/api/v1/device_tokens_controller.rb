module Api
  module V1
    class DeviceTokensController < BaseController
      before_action :require_organization!

      # POST /api/v1/device_tokens
      # Register a device token for the current user
      def create
        authorize DeviceToken

        token = DeviceToken.find_or_initialize_by(
          user:         current_user,
          organization: current_organization,
          token:        token_params[:token]
        )
        token.assign_attributes(
          platform:    token_params[:platform],
          device_name: token_params[:device_name],
          active:      true
        )

        if token.save
          render_created({ id: token.id, token: token.token, platform: token.platform })
        else
          render_errors(token.errors.full_messages)
        end
      end

      # DELETE /api/v1/device_tokens/:id
      # Deregister a device token (e.g. on logout)
      def destroy
        token = DeviceToken.find_by(
          id:           params[:id],
          user:         current_user,
          organization: current_organization
        )

        authorize(token || DeviceToken)

        if token
          token.update!(active: false)
          head :no_content
        else
          render json: { errors: ["Not found"] }, status: :not_found
        end
      end

      private

      def token_params
        params.require(:device_token).permit(:token, :platform, :device_name)
      end
    end
  end
end
