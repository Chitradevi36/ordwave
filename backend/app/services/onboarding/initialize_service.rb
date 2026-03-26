module Onboarding
  class InitializeService
    Result = Struct.new(:success?, :organization, :membership, :token, :errors, keyword_init: true)

    def initialize(user:, org_name:, branch_name:, branch_code:, city: nil, state: nil, gst_number: nil, contact_phone: nil, pan: nil, business_type: nil)
      @user = user
      @org_name = org_name
      @branch_name = branch_name
      @branch_code = branch_code
      @city = city
      @state = state
      @gst_number = gst_number
      @contact_phone = contact_phone
      @pan = pan
      @business_type = business_type
    end

    def call
      begin
        owner_role = Role.fetch!('owner')

        # Check if user already has an organization (idempotency)
        existing_membership = @user.memberships.where(role_id: owner_role.id).first
        if existing_membership
          # User already has an organization as owner, return it
          return Result.new(
            success?: true,
            organization: existing_membership.organization,
            membership: existing_membership,
            errors: []
          )
        end

        organization = nil
        membership = nil

        ActiveRecord::Base.transaction do
          # Create organization with user's plan (denormalized)
          organization = Organization.create!(
            name:          @org_name,
            plan:          @user.plan,
            city:          @city,
            state:         @state,
            gst_number:    @gst_number,
            pan:           @pan,
            contact_email: @user.email,
            contact_phone: @contact_phone,
            active:        true,
            settings:      { business_type: @business_type }.compact
          )

          # Create first branch
          branch = Branch.create!(
            name:         @branch_name,
            code:         @branch_code,
            city:         @city,
            state:        @state,
            organization: organization,
            active:       true
          )

          # Create owner membership
          membership = Membership.create!(
            user:         @user,
            organization: organization,
            branch:       branch,
            role:         owner_role,
            active:       true
          )

          # Create onboarding progress
          OnboardingProgress.create!(
            user:         @user,
            organization: organization
          )
        end

        Result.new(
          success?: true,
          organization: organization,
          membership: membership,
          token: nil,
          errors: []
        )
      rescue ActiveRecord::RecordInvalid => e
        Result.new(
          success?: false,
          organization: nil,
          membership: nil,
          token: nil,
          errors: e.record.errors.full_messages
        )
      rescue StandardError => e
        Result.new(
          success?: false,
          organization: nil,
          membership: nil,
          token: nil,
          errors: [e.message]
        )
      end
    end
  end
end
