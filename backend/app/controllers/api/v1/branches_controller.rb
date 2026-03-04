module Api
  module V1
    class BranchesController < BaseController
      before_action :require_organization!

      def index
        branches = paginate(policy_scope(Branch).active)
        render_success(
          branches.map { |b| serialize_branch(b) },
          meta: pagination_meta(branches)
        )
      end

      def show
        branch = current_organization.branches.not_deleted.find(params[:id])
        authorize branch
        render_success(serialize_branch(branch))
      end

      def create
        authorize Branch.new(organization: current_organization)

        branch = current_organization.branches.build(branch_params)
        if branch.save
          render_created(serialize_branch(branch))
        else
          render_errors(branch.errors.full_messages)
        end
      end

      def update
        branch = current_organization.branches.not_deleted.find(params[:id])
        authorize branch

        if branch.update(branch_params)
          render_success(serialize_branch(branch))
        else
          render_errors(branch.errors.full_messages)
        end
      end

      def settings
        branch = current_organization.branches.not_deleted.find(params[:id])
        authorize branch, :show?
        render_success(serialize_branch_with_settings(branch))
      end

      def update_settings
        branch = current_organization.branches.not_deleted.find(params[:id])
        authorize branch, :update_settings?

        result = Settings::UpdateBranchService.new(branch: branch, params: settings_params).call

        if result.success?
          render_success(serialize_branch_with_settings(result.branch))
        else
          render_errors(result.errors)
        end
      end

      private

      def branch_params
        params.require(:branch).permit(:name, :code, :city, :state, :address, :pincode, :active)
      end

      def settings_params
        params.permit(
          :name, :code, :city, :state, :address, :pincode, :active,
          settings: %i[credit_limit credit_terms_days opening_time closing_time
                       min_order_value days_off payment_modes]
        )
      end

      def serialize_branch(branch)
        {
          id:              branch.id,
          name:            branch.name,
          code:            branch.code,
          city:            branch.city,
          state:           branch.state,
          address:         branch.address,
          pincode:         branch.pincode,
          active:          branch.active,
          organization_id: branch.organization_id,
          created_at:      branch.created_at
        }
      end

      def serialize_branch_with_settings(branch)
        serialize_branch(branch).merge(settings: branch.settings)
      end
    end
  end
end
