module Api
  module V1
    class UsersController < BaseController
      before_action :require_organization!

      def index
        users = paginate(policy_scope(User).active)
        render_success(
          users.map { |u| serialize_user(u) },
          meta: pagination_meta(users)
        )
      end

      def show
        user = User.active.find(params[:id])
        authorize user
        render_success(serialize_user(user))
      end

      def create
        authorize User.new

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
          render_success(serialize_user(user))
        else
          render_errors(user.errors.full_messages)
        end
      end

      private

      def user_create_params
        params.require(:user)
              .permit(:email, :password, :first_name, :last_name, :phone)
              .to_h.symbolize_keys
      end

      def user_update_params
        params.require(:user).permit(:first_name, :last_name, :phone, :active)
      end

      def serialize_user(user)
        {
          id:         user.id,
          email:      user.email,
          first_name: user.first_name,
          last_name:  user.last_name,
          full_name:  user.full_name,
          phone:      user.phone,
          active:     user.active,
          created_at: user.created_at
        }
      end
    end
  end
end
