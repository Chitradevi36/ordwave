module Api
  module V1
    class OrganizationsController < BaseController
      # No org-header required — users act on orgs they belong to via params[:id]
      skip_before_action :set_current_organization

      def index
        organizations = policy_scope(Organization).active
        render_success(organizations.map { |o| serialize_org(o) },
                       meta: { total_count: organizations.size })
      end

      def show
        organization = Organization.active.find(params[:id])
        authorize organization
        render_success(serialize_org(organization))
      end

      def create
        authorize Organization.new
        result = Organizations::CreateOrganizationService.new(
          creator: current_user,
          **org_params
        ).call

        if result.success?
          render_created(serialize_org(result.organization))
        else
          render_errors(result.errors)
        end
      end

      def update
        organization = Organization.active.find(params[:id])
        authorize organization

        if organization.update(update_params)
          render_success(serialize_org(organization))
        else
          render_errors(organization.errors.full_messages)
        end
      end

      def settings
        organization = Organization.active.find(params[:id])
        authorize organization, :show?
        render_success(serialize_org_with_settings(organization))
      end

      def update_settings
        organization = Organization.active.find(params[:id])
        authorize organization, :update_settings?

        result = Settings::UpdateOrganizationService.new(
          organization: organization,
          params:       settings_params
        ).call

        if result.success?
          render_success(serialize_org_with_settings(result.organization))
        else
          render_errors(result.errors)
        end
      end

      private

      def org_params
        params.require(:organization)
              .permit(:name, :gst_number, :address,
                      :city, :state, :pincode, :contact_email, :contact_phone)
              .to_h.symbolize_keys
      end

      def update_params
        params.require(:organization)
              .permit(:name, :gst_number, :address,
                      :city, :state, :pincode, :contact_email, :contact_phone, :active)
      end

      def settings_params
        params.permit(
          :name, :gst_number, :pan, :address, :city, :state, :pincode,
          :contact_email, :contact_phone, :logo_url, :timezone, :currency,
          settings: {}
        )
      end

      def serialize_org(org)
        {
          id:            org.id,
          name:          org.name,
          slug:          org.slug,
          active:        org.active,
          gst_number:    org.gst_number,
          city:          org.city,
          state:         org.state,
          contact_email: org.contact_email,
          contact_phone: org.contact_phone,
          created_at:    org.created_at
        }
      end

      def serialize_org_with_settings(org)
        serialize_org(org).merge(
          address:  org.address,
          pincode:  org.pincode,
          pan:      org.pan,
          logo_url: org.logo_url,
          timezone: org.timezone,
          currency: org.currency,
          settings: org.settings
        )
      end

      # Pundit needs a nil org context here since this controller doesn't use X-Organization-Id
      def pundit_user
        UserContext.new(user: current_user, organization: nil)
      end
    end
  end
end
