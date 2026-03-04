module Api
  module V1
    class InvitationsController < BaseController
      before_action :require_organization!, except: :accept

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

      # POST /api/v1/invitations/accept  — requires auth; no org context
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
