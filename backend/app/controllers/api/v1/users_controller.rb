module Api
  module V1
    class UsersController < BaseController
      before_action :require_organization!

      def index
        scope = policy_scope(User).active
        scope = apply_filters(scope)
        users = paginate(scope)

        render_success(
          users.map { |u| serialize_user(u, with_membership: true) },
          meta: pagination_meta(users)
        )
      end

      def show
        user = User.active.find(params[:id])
        authorize user
        render_success(serialize_user(user, with_membership: true))
      end

      def create
        authorize User.new
        plan_limits.enforce_user_limit!

        result = Users::CreateUserService.new(**user_create_params).call

        if result.success?
          render_created(serialize_user(result.user))
        else
          render_errors(result.errors)
        end
      end

      def update
        user = User.active.find(params[:id])
        authorize user

        if user.update(user_update_params)
          render_success(serialize_user(user, with_membership: true))
        else
          render_errors(user.errors.full_messages)
        end
      end

      def invite
        authorize User.new, :invite?
        plan_limits.enforce_user_limit!

        result = Users::InviteService.new(
          email:        params[:email],
          role_id:      params[:role_id],
          branch_id:    params[:branch_id],
          phone:        params[:phone],
          organization: current_organization,
          invited_by:   current_user
        ).call

        if result.success?
          payload = { invitation_id: result.invitation.id, email: result.invitation.email }
          payload[:token] = result.token if result.token.present?
          render_created(payload)
        else
          render_errors(result.errors)
        end
      end

      def deactivate
        user   = User.active.find(params[:id])
        authorize user, :deactivate?

        result = Users::DeactivateService.new(
          user:         user,
          organization: current_organization,
          initiated_by: current_user
        ).call

        if result.success?
          render_success({ message: 'User deactivated from organization' })
        else
          render_errors(result.errors)
        end
      end

      private

      def apply_filters(scope)
        scope = filter_by_role(scope)    if params[:role_id].present? || params[:role_name].present?
        scope = filter_by_branch(scope)  if params[:branch_id].present?
        scope = filter_by_status(scope)  if params[:status].present?
        scope = filter_by_query(scope)   if params[:q].present?
        scope
      end

      def filter_by_role(scope)
        role_id = params[:role_id] || (params[:role_name].present? && Role.find_by(name: params[:role_name])&.id)
        return scope unless role_id

        scope.joins(:memberships)
             .where(memberships: { organization: current_organization, role_id: role_id,
                                   deleted_at: nil, active: true })
      end

      def filter_by_branch(scope)
        scope.joins(:memberships)
             .where(memberships: { organization: current_organization, branch_id: params[:branch_id],
                                   deleted_at: nil, active: true })
      end

      def filter_by_status(scope)
        active_val = params[:status] == 'active'
        scope.where(active: active_val)
      end

      def filter_by_query(scope)
        q = "%#{params[:q].strip}%"
        scope.where('users.first_name ILIKE :q OR users.last_name ILIKE :q OR users.email ILIKE :q', q: q)
      end

      def user_create_params
        params.require(:user)
              .permit(:email, :password, :first_name, :last_name, :phone)
              .to_h.symbolize_keys
      end

      def user_update_params
        params.require(:user).permit(:first_name, :last_name, :phone, :active)
      end

      def serialize_user(user, with_membership: false)
        data = {
          id:         user.id,
          email:      user.email,
          first_name: user.first_name,
          last_name:  user.last_name,
          full_name:  user.full_name,
          phone:      user.phone,
          active:     user.active,
          created_at: user.created_at
        }

        if with_membership && defined?(current_organization) && current_organization
          membership = user.memberships.active.find_by(organization: current_organization)
          if membership
            data[:membership] = {
              id:         membership.id,
              role:       { id: membership.role_id, name: membership.role&.name },
              branch:     { id: membership.branch_id, name: membership.branch&.name },
              status:     membership.status,
              created_at: membership.created_at
            }
          end
        end

        data
      end
    end
  end
end
