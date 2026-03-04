module Api
  module V1
    class RolesController < BaseController
      # Roles are system-wide; no org context required
      skip_before_action :set_current_organization

      def index
        roles = policy_scope(Role)
        render_success(roles.map { |r| serialize_role(r) })
      end

      private

      def serialize_role(role)
        {
          id:          role.id,
          name:        role.name,
          description: role.description
        }
      end

      def pundit_user
        UserContext.new(user: current_user, organization: nil)
      end

      def current_user
        @current_user ||= User.active.find_by(id: jwt_payload['user_id'])
      end
    end
  end
end
