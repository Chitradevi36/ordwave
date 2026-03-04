module Users
  class DeactivateService
    Result = Struct.new(:success?, :errors, keyword_init: true)

    def initialize(user:, organization:, initiated_by:)
      @user         = user
      @organization = organization
      @initiated_by = initiated_by
    end

    def call
      return error_result(['Cannot deactivate yourself']) if @user == @initiated_by

      membership = @user.memberships.active.find_by(organization: @organization)
      return error_result(['User is not an active member of this organization']) unless membership

      owner_membership = @user.memberships.active.find_by(organization: @organization, role: Role.find_by(name: 'owner'))
      return error_result(['Cannot deactivate the organization owner']) if owner_membership.present?

      ActiveRecord::Base.transaction do
        # Soft-delete all memberships for this user in this org
        @organization.memberships.active.where(user: @user).each(&:soft_delete!)
      end

      Result.new(success?: true, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.record.errors.full_messages)
    end

    private

    def error_result(errors)
      Result.new(success?: false, errors: errors)
    end
  end
end
