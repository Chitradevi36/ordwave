module Api
  module V1
    class OrganizationsController < BaseController
      def index
        organizations = Organization.all
        render json: { data: organizations }
      end

      def show
        organization = Organization.find(params[:id])
        render json: { data: organization }
      end

      def create
        organization = Organization.new(organization_params)
        if organization.save
          render json: { data: organization }, status: :created
        else
          render json: { errors: organization.errors }, status: :unprocessable_entity
        end
      end

      def update
        organization = Organization.find(params[:id])
        if organization.update(organization_params)
          render json: { data: organization }
        else
          render json: { errors: organization.errors }, status: :unprocessable_entity
        end
      end

      private

      def organization_params
        params.require(:organization).permit(:name, :slug, :plan, :active)
      end
    end
  end
end
