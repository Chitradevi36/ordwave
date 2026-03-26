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
          
          # Store business type and operating model in org settings
          update_organization_settings if @business_type.present? || @operating_model.present?
          
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

    def update_organization_settings
      new_settings = @organization.settings || {}
      new_settings['business_type'] = @business_type if @business_type.present?
      new_settings['operating_model'] = @operating_model if @operating_model.present?

      unless @organization.update(settings: new_settings)
        raise "Failed to update organization settings: #{@organization.errors.full_messages.join(', ')}"
      end
    end
  end
end
