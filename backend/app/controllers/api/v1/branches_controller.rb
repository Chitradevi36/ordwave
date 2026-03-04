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

      private

      def branch_params
        params.require(:branch).permit(:name, :code, :city, :state, :address, :pincode, :active)
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
    end
  end
end
