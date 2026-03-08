# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Typed view over an AccountingIntegration's config_json for the Tally
      # provider.  All access goes through this class — no direct hash reads
      # in the adapter layer.
      #
      # The 16 named config keys correspond to the typed accessors defined on
      # AccountingIntegration:
      #
      #   General:    host, port, company_name, username, password, timeout_seconds
      #   Sync modes: realtime_enabled, batch_export_enabled, auto_sync_on_save
      #   Behaviour:  default_currency, fiscal_year_start_month,
      #               cost_centre_tracking, bill_by_bill_settlement,
      #               multi_godown_support, stock_valuation_method,
      #               voucher_numbering_mode
      class Configuration
        include Constants

        # @param integration [AccountingIntegration]
        def initialize(integration)
          @integration = integration
          @cfg = integration.config_json || {}
        end

        # -----------------------------------------------------------------------
        # Connection
        # -----------------------------------------------------------------------

        def host
          @cfg["host"].presence || Constants::DEFAULT_HOST
        end

        def port
          (@cfg["port"] || Constants::DEFAULT_PORT).to_i
        end

        # Full base URL for Tally's HTTP XML import endpoint.
        def endpoint_url
          "http://#{host}:#{port}"
        end

        # -----------------------------------------------------------------------
        # Company / identity
        # -----------------------------------------------------------------------

        def company_name
          @cfg["company_name"].to_s.strip
        end

        def username
          @cfg["username"].presence
        end

        def password
          @cfg["password"].presence
        end

        def timeout_seconds
          (@cfg["timeout_seconds"] || 30).to_i
        end

        # -----------------------------------------------------------------------
        # Sync mode flags
        # -----------------------------------------------------------------------

        def realtime_enabled?
          cast_bool(@cfg["realtime_enabled"])
        end
        alias realtime_agent? realtime_enabled?

        def batch_export_enabled?
          cast_bool(@cfg["batch_export_enabled"])
        end
        alias batch_export? batch_export_enabled?

        def auto_sync_on_save?
          cast_bool(@cfg["auto_sync_on_save"])
        end

        # -----------------------------------------------------------------------
        # Accounting behaviour
        # -----------------------------------------------------------------------

        def default_currency
          @cfg["default_currency"].presence || "INR"
        end

        def fiscal_year_start_month
          (@cfg["fiscal_year_start_month"] || 4).to_i
        end

        def cost_centre_tracking?
          cast_bool(@cfg["cost_centre_tracking"])
        end

        def bill_by_bill_settlement?
          cast_bool(@cfg["bill_by_bill_settlement"])
        end

        def multi_godown_support?
          cast_bool(@cfg["multi_godown_support"])
        end

        def stock_valuation_method
          @cfg["stock_valuation_method"].presence || "FIFO"
        end

        def voucher_numbering_mode
          @cfg["voucher_numbering_mode"].presence || "automatic"
        end

        # -----------------------------------------------------------------------
        # Validation helpers
        # -----------------------------------------------------------------------

        # Returns true when all Phase 1 required fields are present and
        # non-blank.
        def valid_for_phase1?
          missing_required_fields.empty?
        end

        # Returns an Array of string keys that are required but blank.
        def missing_required_fields
          Constants::PHASE1_REQUIRED_CONFIG_KEYS.reject do |key|
            @cfg[key].present?
          end
        end

        # -----------------------------------------------------------------------
        # Serialisation
        # -----------------------------------------------------------------------

        # @return [Hash] all resolved config values — useful for logging/debug
        def to_h
          {
            host: host,
            port: port,
            endpoint_url: endpoint_url,
            company_name: company_name,
            username: username,
            timeout_seconds: timeout_seconds,
            realtime_enabled: realtime_enabled?,
            batch_export_enabled: batch_export_enabled?,
            auto_sync_on_save: auto_sync_on_save?,
            default_currency: default_currency,
            fiscal_year_start_month: fiscal_year_start_month,
            cost_centre_tracking: cost_centre_tracking?,
            bill_by_bill_settlement: bill_by_bill_settlement?,
            multi_godown_support: multi_godown_support?,
            stock_valuation_method: stock_valuation_method,
            voucher_numbering_mode: voucher_numbering_mode
          }
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        def cast_bool(value)
          return false if value.nil?
          return value if [true, false].include?(value)

          value.to_s.casecmp("true").zero?
        end
      end
    end
  end
end
