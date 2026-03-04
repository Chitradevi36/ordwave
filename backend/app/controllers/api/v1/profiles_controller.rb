module Api
  module V1
    class ProfilesController < BaseController
      skip_before_action :set_current_organization

      after_action :verify_authorized

      def show
        authorize current_user, policy_class: UserPolicy
        render_success(serialize_user(current_user))
      end

      def update
        authorize current_user, policy_class: UserPolicy
        if current_user.update(profile_params)
          render_success(serialize_user(current_user))
        else
          render_errors(current_user.errors.full_messages)
        end
      end

      private

      def profile_params
        params.require(:user).permit(:first_name, :last_name, :phone)
      end

      def serialize_user(user)
        {
          id:         user.id,
          email:      user.email,
          first_name: user.first_name,
          last_name:  user.last_name,
          full_name:  user.full_name,
          phone:      user.phone,
          plan:       user.plan,
          active:     user.active,
          created_at: user.created_at,
          organizations: user.organizations.active.map do |org|
            {
              id:   org.id,
              name: org.name,
              slug: org.slug,
              role: user.role_in(org)&.name
            }
          end
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
