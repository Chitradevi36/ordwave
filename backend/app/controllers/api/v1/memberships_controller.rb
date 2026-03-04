module Api
  module V1
    class MembershipsController < BaseController
      before_action :require_organization!

      def index
        memberships = paginate(policy_scope(Membership))
        render_success(
          memberships.map { |m| serialize_membership(m) },
          meta: pagination_meta(memberships)
        )
      end

      def create
        authorize Membership.new(organization: current_organization)

        user   = User.active.find(params.dig(:membership, :user_id))
        branch = current_organization.branches.active.find(params.dig(:membership, :branch_id))
        role   = Role.find_by!(name: params.dig(:membership, :role))

        result = Memberships::CreateMembershipService.new(
          user:         user,
          organization: current_organization,
          branch:       branch,
          role:         role
        ).call

        if result.success?
          render_created(serialize_membership(result.membership))
        else
          render_errors(result.errors)
        end
      end

      def destroy
        membership = current_organization.memberships.find(params[:id])
        authorize membership

        membership.soft_delete!
        head :no_content
      end

      private

      def serialize_membership(membership)
        {
          id:              membership.id,
          user_id:         membership.user_id,
          user_name:       membership.user.full_name,
          user_email:      membership.user.email,
          organization_id: membership.organization_id,
          branch_id:       membership.branch_id,
          branch_name:     membership.branch.name,
          role:            membership.role.name,
          active:          membership.active,
          created_at:      membership.created_at
        }
      end
    end
  end
end
