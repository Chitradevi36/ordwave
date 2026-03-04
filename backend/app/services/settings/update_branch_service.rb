module Settings
  class UpdateBranchService
    Result = Struct.new(:success?, :branch, :errors, keyword_init: true)

    PERMITTED_BASE = %i[name code city state address pincode active].freeze

    PERMITTED_SETTINGS = %w[
      credit_limit credit_terms_days payment_modes
      opening_time closing_time days_off min_order_value
    ].freeze

    def initialize(branch:, params:)
      @branch = branch
      @params = params.to_h.with_indifferent_access
    end

    def call
      base_attrs    = @params.slice(*PERMITTED_BASE.map(&:to_s))
      settings_hash = @params[:settings].is_a?(Hash) ? @params[:settings].slice(*PERMITTED_SETTINGS) : {}

      merged_settings = @branch.settings.merge(settings_hash)

      if @branch.update(base_attrs.merge(settings: merged_settings))
        Result.new(success?: true, branch: @branch, errors: [])
      else
        Result.new(success?: false, branch: @branch,
                   errors: @branch.errors.full_messages)
      end
    end
  end
end
