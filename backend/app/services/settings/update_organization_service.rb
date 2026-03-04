module Settings
  class UpdateOrganizationService
    Result = Struct.new(:success?, :organization, :errors, keyword_init: true)

    PERMITTED_BASE = %i[
      name contact_email contact_phone address city state pincode
      gst_number pan logo_url timezone currency
    ].freeze

    PERMITTED_SETTINGS = %w[
      credit_limit_default credit_terms_days payment_modes
      date_format fiscal_year_start
    ].freeze

    def initialize(organization:, params:)
      @organization = organization
      @params       = params.to_h.with_indifferent_access
    end

    def call
      base_attrs    = @params.slice(*PERMITTED_BASE.map(&:to_s))
      settings_hash = @params[:settings].is_a?(Hash) ? @params[:settings].slice(*PERMITTED_SETTINGS) : {}

      merged_settings = @organization.settings.merge(settings_hash)

      if @organization.update(base_attrs.merge(settings: merged_settings))
        Result.new(success?: true, organization: @organization, errors: [])
      else
        Result.new(success?: false, organization: @organization,
                   errors: @organization.errors.full_messages)
      end
    end
  end
end
