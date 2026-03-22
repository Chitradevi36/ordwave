module Api
  module V1
    class InvitationsController < BaseController
      skip_before_action :authenticate_user!, only: [:validate, :accept_with_signup]
      skip_before_action :set_current_organization, only: [:validate, :accept_with_signup]
      skip_before_action :set_current_context, only: [:validate, :accept_with_signup]
      before_action :require_organization!, except: [:accept, :accept_with_signup, :validate]

      def index
        invitations = paginate(policy_scope(Invitation).order(created_at: :desc))
        authorize Invitation.new(organization: current_organization)

        render_success(
          invitations.map { |i| serialize_invitation(i) },
          meta: pagination_meta(invitations)
        )
      end

      def create
        authorize Invitation.new(organization: current_organization)

        result = Users::InviteService.new(
          email:        params[:email],
          role_id:      params[:role_id],
          branch_id:    params[:branch_id],
          organization: current_organization,
          invited_by:   current_user
        ).call

        if result.success?
          payload = serialize_invitation(result.invitation)
          payload[:token] = result.token if result.token.present?
          render_created(payload)
        else
          render_errors(result.errors)
        end
      end

      def destroy
        invitation = current_organization.invitations.find(params[:id])
        authorize invitation

        if invitation.pending?
          invitation.revoke!
          render_success({ message: 'Invitation revoked' })
        else
          render_errors(["Invitation cannot be revoked (status: #{invitation.status})"])
        end
      end

      # GET /api/v1/invitations/validate?token=xxx — no auth required
      # Returns invitation details so users can see who invited them
      def validate
        skip_authorization

        digest     = Invitation.digest(params[:token])
        invitation = Invitation.pending.find_by(token_digest: digest)

        return render_errors(['Invitation not found or already used']) unless invitation
        return render_errors(['Invitation has expired']) if invitation.expired?

        # Check if this email already has an account
        user_exists = User.exists?(email: invitation.email)

        render_success({
          email:               invitation.email,
          organization_name:   invitation.organization.name,
          organization_id:     invitation.organization.id,
          role_name:           invitation.role&.name,
          invited_by_name:     invitation.invited_by&.full_name,
          expires_at:          invitation.expires_at.iso8601,
          user_exists:         user_exists
        })
      end

      # POST /api/v1/invitations/accept — requires auth; existing user
      def accept
        skip_authorization

        result = Invitations::AcceptService.new(
          token: params[:token],
          user:  current_user
        ).call

        if result.success?
          render_success({
            message:         'Invitation accepted',
            organization_id: result.membership.organization_id
          })
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/invitations/accept_with_signup — new user signup + invite
      def accept_with_signup
        skip_authorization

        result = Invitations::AcceptWithSignupService.new(
          token:                    params[:token],
          password:                 params[:password],
          password_confirmation:    params[:password_confirmation]
        ).call

        if result.success?
          render_created({
            message:         'Account created and invitation accepted',
            token:           result.token,
            user:            result.user,
            organization_id: result.membership.organization_id
          })
        else
          render_errors(result.errors)
        end
      end

      private

      def serialize_invitation(invitation)
        {
          id:              invitation.id,
          email:           invitation.email,
          status:          invitation.status,
          role:            { id: invitation.role_id, name: invitation.role&.name },
          branch:          invitation.branch ? { id: invitation.branch_id, name: invitation.branch.name } : nil,
          invited_by:      { id: invitation.invited_by_id, name: invitation.invited_by&.full_name },
          expires_at:      invitation.expires_at,
          accepted_at:     invitation.accepted_at,
          created_at:      invitation.created_at
        }
      end
    end
  end
end
