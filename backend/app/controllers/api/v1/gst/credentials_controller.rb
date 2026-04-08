module Api
  module V1
    module Gst
      class CredentialsController < Api::V1::BaseController
        before_action :require_organization!

        # GET /api/v1/gst/credentials
        def show
          authorize current_organization, :manage_gst_credentials?
          
          creds = current_organization.settings.dig("gst_credentials") || {}
          render json: {
            data: {
              irp_username: creds["irp_username"],
              irp_environment: creds["irp_environment"] || "sandbox",
              configured: current_organization.gst_credentials_configured?,
              configured_at: creds["configured_at"],
              configured_by_id: creds["configured_by_id"]
            }
          }
        end

        # POST /api/v1/gst/credentials/test_connection
        def test_connection
          authorize current_organization, :manage_gst_credentials?
          
          username = params[:irp_username].presence || current_organization.gst_irp_username
          password = params[:irp_password].presence || current_organization.gst_irp_password
          environment = params[:irp_environment].presence || current_organization.gst_irp_environment
          
          unless username.present? && password.present?
            return render json: { errors: ["Credentials not configured"] }, status: :unprocessable_entity
          end
          
          result = Gst::TestConnectionService.call(
            organization: current_organization,
            username: username,
            password: password,
            environment: environment
          )
          
          if result.success?
            render json: { data: { message: result.message, success: true } }
          else
            render json: { errors: [result.message] }, status: :bad_request
          end
        end
      end
    end
  end
end
