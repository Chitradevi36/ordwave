module Onboarding
  class SetupService
    Result = Struct.new(:success?, :organization, :errors, keyword_init: true)

    def initialize(
      user:,
      organization:,
      business_type: nil,
      org_details: {},
      branch_details: {},
      operating_model: []
    )
      @user = user
      @organization = organization
      @business_type = business_type
      @org_details = org_details || {}
      @branch_details = branch_details || {}
      @operating_model = Array(operating_model)
    end

    def call
      begin
        ActiveRecord::Base.transaction do
          # Update organization details
          update_organization if @org_details.present?
          
          # Update first branch details
          update_first_branch if @branch_details.present?
          
          # Store operating model in org metadata (if we add jsonb field later)
          # For now, it's just tracked in the workflow
          
          Result.new(success?: true, organization: @organization.reload, errors: [])
        end
      rescue StandardError => e
        Result.new(success?: false, organization: nil, errors: [e.message])
      end
    end

    private

    def update_organization
      org_attrs = {
        name: @org_details[:org_name],
        gst_number: @org_details[:gstin],
        city: @org_details[:city],
        state: @org_details[:state],
        contact_phone: @org_details[:phone]
      }.compact

      unless @organization.update(org_attrs)
        raise "Failed to update organization: #{@organization.errors.full_messages.join(', ')}"
      end
    end

    def update_first_branch
      branch = @organization.branches.first
      return unless branch

      branch_attrs = {
        name: @branch_details[:branch_name],
        code: @branch_details[:branch_code],
        address: @branch_details[:address],
        city: @branch_details[:city],
        state: @branch_details[:branch_state],
        pincode: @branch_details[:pincode]
      }.compact

      unless branch.update(branch_attrs)
        raise "Failed to update branch: #{branch.errors.full_messages.join(', ')}"
      end
    end
  end
end
