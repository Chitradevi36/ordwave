module Organizations
  class CreateOrganizationService
    Result = Struct.new(:success?, :organization, :membership, :errors, keyword_init: true)

    def initialize(name:, creator:, **attrs)
      @name    = name
      @creator = creator
      @attrs   = attrs
    end

    def call
      organization = nil
      membership   = nil

      ActiveRecord::Base.transaction do
        # Use creator's plan for the organization (denormalized copy)
        organization = Organization.create!(
          name:          @name,
          plan:          @creator.plan,
          active:        true,
          **@attrs.slice(:gst_number, :address, :city, :state, :pincode, :contact_email, :contact_phone)
        )

        owner_role = Role.fetch!('owner')
        # Use the first branch (created automatically) or a default org-level branch
        branch = organization.branches.create!(
          name:   'Head Office',
          code:   "#{organization.slug.upcase[0..4]}-HO",
          active: true
        )

        membership = Membership.create!(
          user:         @creator,
          organization: organization,
          branch:       branch,
          role:         owner_role,
          active:       true
        )
      end

      Result.new(success?: true, organization: organization, membership: membership, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, organization: nil, membership: nil, errors: e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      Result.new(success?: false, organization: nil, membership: nil, errors: [e.message])
    end
  end
end
