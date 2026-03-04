module Invitations
  class AcceptService
    Result = Struct.new(:success?, :membership, :errors, keyword_init: true)

    def initialize(token:, user:)
      @token = token
      @user  = user
    end

    def call
      digest     = Invitation.digest(@token)
      invitation = Invitation.pending.find_by(token_digest: digest)

      return error_result(['Invitation not found or already used']) unless invitation
      return error_result(['Invitation has expired'])              if invitation.expired?

      already_member = Membership.active
                                 .exists?(user: @user, organization: invitation.organization)

      return error_result(['You are already a member of this organization']) if already_member

      membership = nil

      ActiveRecord::Base.transaction do
        target_branch = invitation.branch || invitation.organization.branches.active.first
        return error_result(['Organization has no active branch']) unless target_branch

        membership = Membership.create!(
          user:         @user,
          organization: invitation.organization,
          branch:       target_branch,
          role:         invitation.role,
          active:       true,
          status:       'active'
        )

        invitation.update!(status: 'accepted', accepted_at: Time.current)
      end

      Result.new(success?: true, membership: membership, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.record.errors.full_messages)
    end

    private

    def error_result(errors)
      Result.new(success?: false, membership: nil, errors: errors)
    end
  end
end
