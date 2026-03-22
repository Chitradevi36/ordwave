# frozen_string_literal: true

module Web
  module Accounting
    # Manages accounting provider integrations for the current organization.
    #
    # Screens:
    #   GET  /web/accounting/integrations            — index (provider card list)
    #   GET  /web/accounting/integrations/:id        — show  (summary + mappings)
    #   GET  /web/accounting/integrations/:id/edit   — edit  (configuration form)
    #   PATCH/PUT /web/accounting/integrations/:id   — update
    #   POST /web/accounting/integrations/:id/test_configuration
    #   POST /web/accounting/integrations/:id/mark_connected
    #   POST /web/accounting/integrations/:id/mark_disconnected
    class IntegrationsController < Web::BaseController
      helper Web::AccountingHelper

      before_action :set_integration, only: %i[show edit update
                                                test_configuration
                                                mark_connected mark_disconnected]

      # GET /web/accounting/integrations
      def index
        @integrations = policy_scope(AccountingIntegration)
                          .includes(:accounting_mappings)
                          .order(:provider)
        authorize AccountingIntegration
        @providers_configured = @integrations.map(&:provider).map(&:to_s)
        @tally_integration    = @integrations.find { |i| i.provider.to_s == "tally" }
      end

      # GET /web/accounting/integrations/:id
      def show
        authorize @integration
        @mappings          = @integration.accounting_mappings.order(:mapping_key)
        @recent_sync_count = @integration.accounting_sync_records.where("created_at > ?", 24.hours.ago).count
        @failed_sync_count = @integration.accounting_sync_records.failed.count
        @recent_exports    = @integration.accounting_export_files.order(created_at: :desc).limit(5)
      end

      # GET /web/accounting/integrations/:id/edit
      def edit
        authorize @integration
        @mappings = @integration.accounting_mappings.order(:mapping_key)
      end

      # PATCH /web/accounting/integrations/:id
      def update
        authorize @integration

        if @integration.update(integration_params)
          apply_config_fields!
          if @integration.save
            redirect_to web_accounting_integration_path(@integration),
                        notice: "Integration settings updated successfully."
          else
            render :edit, status: :unprocessable_entity
          end
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # POST /web/accounting/integrations/:id/test_configuration
      def test_configuration
        authorize @integration

        adapter = ::Accounting::Adapters::Factory.build(@integration)
        adapter.validate_config!
        redirect_to web_accounting_integration_path(@integration),
                    notice: "Configuration is valid."
      rescue ::Accounting::Adapters::InvalidConfigurationError => e
        redirect_to web_accounting_integration_path(@integration),
                    alert: "Configuration invalid: #{e.message}"
      rescue StandardError => e
        redirect_to web_accounting_integration_path(@integration),
                    alert: "Validation error: #{e.message}"
      end

      # POST /web/accounting/integrations/:id/mark_connected
      def mark_connected
        authorize @integration
        @integration.mark_connected!
        redirect_to web_accounting_integration_path(@integration),
                    notice: "Integration marked as connected."
      rescue ActiveRecord::RecordInvalid => e
        redirect_back fallback_location: web_accounting_integration_path(@integration),
                      alert: e.message
      end

      # POST /web/accounting/integrations/:id/mark_disconnected
      def mark_disconnected
        authorize @integration
        @integration.update!(status: "disconnected")
        redirect_to web_accounting_integration_path(@integration),
                    notice: "Integration marked as disconnected."
      rescue ActiveRecord::RecordInvalid => e
        redirect_back fallback_location: web_accounting_integration_path(@integration),
                      alert: e.message
      end

      private

      def set_integration
        @integration = AccountingIntegration
                         .where(organization: current_organization)
                         .find(params[:id])
      end

      # Params for top-level model fields
      # Note: sync_mode is deprecated in Phase 1 (organization workflow settings control sync)
      # Reserved for Phase 2 (realtime agent sync) — do not permit in UI for now
      def integration_params
        params.require(:accounting_integration)
              .permit() # Empty for Phase 1 — all sync configuration at organization level
      end

      # Config fields are written via the config_json accessors.
      # This keeps config_json cleanly updated without nested hash juggling in views.
      def apply_config_fields!
        AccountingIntegration::CONFIG_FIELDS.each do |field|
          next unless params.dig(:accounting_integration, field)

          value = params[:accounting_integration][field]
          @integration.public_send(:"#{field}=", value.presence)
        end
      end
    end
  end
end
