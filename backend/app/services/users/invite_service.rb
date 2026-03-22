module Users
  class InviteService
    Result = Struct.new(:success?, :invitation, :token, :errors, keyword_init: true)

    def initialize(email:, role_id:, branch_id: nil, organization:, invited_by:)
      @email        = email.to_s.downcase.strip
      @role_id      = role_id
      @branch_id    = branch_id
      @organization = organization
      @invited_by   = invited_by
    end

    def call
      return already_member_result if already_member?

      role = Role.find_by(id: @role_id)
      return error_result(['Role not found']) unless role

      branch = @branch_id.present? ? @organization.branches.active.find_by(id: @branch_id) : nil
      return error_result(['Branch not found or inactive']) if @branch_id.present? && branch.nil?

      token  = Invitation.generate_token
      digest = Invitation.digest(token)

      # Revoke any pending invitations for this email+org
      @organization.invitations.pending.where(email: @email).update_all(status: 'revoked')

      invitation = Invitation.create!(
        email:         @email,
        token_digest:  digest,
        organization:  @organization,
        role:          role,
        branch:        branch,
        invited_by:    @invited_by,
        status:        'pending',
        expires_at:    72.hours.from_now
      )

      puts "Generated invitation token: #{token} (digest: #{digest}) for #{@email} to join #{@organization.name} as #{role.name}"
      deliver_email(invitation, token)

      Result.new(success?: true, invitation: invitation, token: dev_token(token), errors: [])
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.record.errors.full_messages)
    end

    private

    def already_member?
      User.joins(:memberships)
          .where(email: @email, memberships: { organization: @organization, deleted_at: nil, active: true })
          .exists?
    end

    def already_member_result
      error_result(["#{@email} is already a member of this organization"])
    end

    def deliver_email(invitation, token)
      InvitationMailer.invite(invitation: invitation, token: token).deliver_later
    rescue StandardError => e
      Rails.logger.error("InvitationMailer failed: #{e.message}")
    end

    # Return raw token only in development/test so acceptance can be tested without email
    def dev_token(token)
      Rails.env.production? ? nil : token
    end

    def error_result(errors)
      Result.new(success?: false, invitation: nil, token: nil, errors: errors)
    end
  end
end
