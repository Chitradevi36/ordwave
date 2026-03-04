module Api
  module V1
    class OnboardingController < BaseController
      before_action :require_organization!, except: [:create]
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def create
        # Create the first organization, branch, and membership
        # This is called after signup when user doesn't have an organization yet
        result = Onboarding::InitializeService.new(
          user: current_user,
          org_name: params[:org_name],
          branch_name: params[:branch_name],
          branch_code: params[:branch_code],
          city: params[:city],
          state: params[:state],
          gst_number: params[:gst_number],
          contact_phone: params[:contact_phone]
        ).call

        if result.success?
          render_success(
            {
              organization: serialize_organization(result.organization),
              message: 'Organization initialized successfully. Please proceed to onboarding.'
            }
          )
        else
          render_errors(result.errors, status: :unprocessable_entity)
        end
      end

      def show
        progress = OnboardingProgress.find_or_create_by!(
          organization: current_organization,
          user:         current_user
        )

        render_success(serialize_progress(progress))
      end

      def setup
        progress = OnboardingProgress.find_or_create_by!(
          organization: current_organization,
          user:         current_user
        )

        result = Onboarding::SetupService.new(
          user: current_user,
          organization: current_organization,
          business_type: params[:business_type],
          org_details: params[:org_details] || {},
          branch_details: params[:branch_details] || {},
          operating_model: params[:operating_model] || []
        ).call

        if result.success?
          # Mark relevant steps as complete
          %w[setup_details].each do |step|
            progress.mark_step_complete!(step) if progress.step_completed?(step) == false
          end

          render_success(
            serialize_progress(progress),
            meta: { message: 'Onboarding setup completed' }
          )
        else
          render_errors(result.errors, status: :unprocessable_entity)
        end
      end

      def complete_step
        progress = OnboardingProgress.find_or_create_by!(
          organization: current_organization,
          user:         current_user
        )

        step_name = params[:step_name]

        begin
          progress.mark_step_complete!(step_name)
          render_success(
            serialize_progress(progress),
            meta: { message: "Step '#{step_name}' marked as complete" }
          )
        rescue ArgumentError => e
          render_errors([e.message], status: :bad_request)
        end
      end

      private

      def serialize_progress(progress)
        {
          organization_id:       progress.organization_id,
          user_id:               progress.user_id,
          completion_percentage: progress.completion_percentage,
          completed:             progress.completed,
          completed_at:          progress.completed_at,
          steps:                 progress.steps.map do |name, data|
            {
              name:         name,
              completed:    data['completed'],
              completed_at: data['completed_at']
            }
          end
        }
      end

      def serialize_organization(org)
        {
          id:    org.id,
          name:  org.name,
          slug:  org.slug,
          city:  org.city,
          state: org.state
        }
      end
    end
  end
end
