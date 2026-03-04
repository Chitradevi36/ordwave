module Memberships
  class CreateMembershipService
    Result = Struct.new(:success?, :membership, :errors, keyword_init: true)

    def initialize(user:, organization:, branch:, role:)
      @user         = user
      @organization = organization
      @branch       = branch
      @role         = role
    end

    def call
      # Prevent duplicate memberships in the same branch
      if Membership.active.exists?(user: @user, organization: @organization, branch: @branch)
        return Result.new(
          success?: false,
          membership: nil,
          errors: ['User already has an active membership in this branch']
        )
      end

      membership = Membership.new(
        user:         @user,
        organization: @organization,
        branch:       @branch,
        role:         @role,
        active:       true
      )

      if membership.save
        Result.new(success?: true, membership: membership, errors: [])
      else
        Result.new(success?: false, membership: nil, errors: membership.errors.full_messages)
      end
    end
  end
end
