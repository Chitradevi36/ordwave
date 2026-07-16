module Settings
  class UpdateOrganizationService
    Result = Struct.new(:success?, :organization, :errors, keyword_init: true)

    PERMITTED_BASE = %i[
      name contact_email contact_phone address city state pincode
      gst_number pan logo_url timezone currency
      order_approval_mode order_approval_threshold order_edit_window_minutes
      dispatch_requires_pick_list dispatch_requires_delivery_proof dispatch_auto_confirm_on_invoice
      return_approval_required return_window_days
      credit_auto_approve_below_pct credit_block_on_overdue_days
      invoice_auto_generate invoice_payment_terms_days invoice_prefix
      sync_auto_on_order_approved sync_auto_on_order_delivered sync_auto_on_payment_received
      sync_auto_on_collection sync_schedule_cron sync_batch_size sync_include_stock_movements
    ].freeze

    PERMITTED_SETTINGS = %w[
      credit_limit_default credit_terms_days payment_modes
      date_format fiscal_year_start
      gst_credentials gst_state_registrations
      order_approval_mode order_approval_threshold order_edit_window_minutes
      dispatch_requires_pick_list dispatch_requires_delivery_proof dispatch_auto_confirm_on_invoice
      return_approval_required return_window_days
      credit_auto_approve_below_pct credit_block_on_overdue_days
      invoice_auto_generate invoice_payment_terms_days invoice_prefix
      sync_auto_on_order_approved sync_auto_on_order_delivered sync_auto_on_payment_received
      sync_auto_on_collection sync_schedule_cron sync_batch_size sync_include_stock_movements
    ].freeze

    def initialize(organization:, params:)
      @organization = organization
      @params       = params.to_h.with_indifferent_access
    end

    def call
      base_attrs    = @params.slice(*PERMITTED_BASE.map(&:to_s))
      settings_hash = @params[:settings].is_a?(Hash) ? @params[:settings].slice(*PERMITTED_SETTINGS) : {}

      # Validate GST settings before merging
      validate_gst_credentials!(settings_hash) if settings_hash["gst_credentials"].present?
      validate_gst_state_registrations!(settings_hash) if settings_hash["gst_state_registrations"].present?

      merged_settings = @organization.settings.merge(settings_hash)

      if @organization.update(base_attrs.merge(settings: merged_settings))
        Result.new(success?: true, organization: @organization, errors: [])
      else
        Result.new(success?: false, organization: @organization,
                   errors: @organization.errors.full_messages)
      end
    end

    private

    def validate_gst_credentials!(settings_hash)
      creds = settings_hash["gst_credentials"]
      
      if creds.is_a?(Hash)
        unless creds["irp_username"].present? && creds["irp_password"].present?
          raise ValidationError, "IRP username and password are required"
        end
        unless %w[sandbox production].include?(creds["irp_environment"])
          raise ValidationError, "IRP environment must be 'sandbox' or 'production'"
        end
        
        # Add metadata
        creds["configured_at"] = Time.current.iso8601
      end
    end

    def validate_gst_state_registrations!(settings_hash)
      registrations = settings_hash["gst_state_registrations"]
      
      return unless registrations.is_a?(Hash)

      registrations.each do |state_code, registration|
        unless registration.is_a?(Hash)
          raise ValidationError, "Each state registration must be a hash"
        end
        
        gstin = registration["gstin"]
        unless gstin.match?(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)
          raise ValidationError, "Invalid GSTIN format for state #{state_code}"
        end
        
        # Validate state code in GSTIN matches
        gstin_state = gstin[0..1]
        unless state_code_matches?(gstin_state, state_code)
          raise ValidationError, "GSTIN state code must match declared state #{state_code}"
        end
        
        # Add metadata
        registration["configured_at"] = Time.current.iso8601
      end
    end

    def state_code_matches?(gstin_state, declared_state)
      # GST state code lookup (01-37)
      state_code_to_abbr = {
        "01" => "AN", "02" => "AP", "03" => "AR", "04" => "AS",
        "05" => "BR", "06" => "CG", "07" => "CH", "08" => "CT",
        "09" => "DL", "10" => "DN", "11" => "GA", "12" => "GJ",
        "13" => "HR", "14" => "HP", "15" => "JK", "16" => "JH",
        "17" => "KA", "18" => "KL", "19" => "LA", "20" => "LD",
        "21" => "MP", "22" => "MH", "23" => "MN", "24" => "ML",
        "25" => "MZ", "26" => "OD", "27" => "PD", "28" => "PB",
        "29" => "RJ", "30" => "SK", "31" => "TN", "32" => "TR",
        "33" => "TS", "34" => "UK", "35" => "UP", "36" => "UT",
        "37" => "WB"
      }
      
      expected_state = state_code_to_abbr[gstin_state]
      expected_state == declared_state
    end

    class ValidationError < StandardError; end
  end
end
