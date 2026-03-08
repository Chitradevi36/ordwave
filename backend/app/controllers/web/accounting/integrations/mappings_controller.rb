# frozen_string_literal: true

module Web
  module Accounting
    module Integrations
      # Manages per-key ledger/group mappings within an integration.
      #
      # Routes are nested under integrations/:integration_id/mappings.
      #
      # UI is embedded in the integration edit/show page; POST/PATCH/DELETE
      # respond with redirects back to that page.
      class MappingsController < Web::BaseController
        before_action :set_integration
        before_action :set_mapping, only: %i[update destroy]

        # POST /web/accounting/integrations/:integration_id/mappings
        def create
          @mapping = @integration.accounting_mappings.build(mapping_params)
          @mapping.organization = current_organization
          authorize @mapping

          if @mapping.save
            redirect_to edit_web_accounting_integration_path(@integration),
                        notice: "Mapping '#{@mapping.display_key}' saved."
          else
            redirect_to edit_web_accounting_integration_path(@integration),
                        alert: @mapping.errors.full_messages.to_sentence
          end
        end

        # PATCH /web/accounting/integrations/:integration_id/mappings/:id
        def update
          authorize @mapping

          if @mapping.update(mapping_params)
            redirect_to edit_web_accounting_integration_path(@integration),
                        notice: "Mapping '#{@mapping.display_key}' updated."
          else
            redirect_to edit_web_accounting_integration_path(@integration),
                        alert: @mapping.errors.full_messages.to_sentence
          end
        end

        # DELETE /web/accounting/integrations/:integration_id/mappings/:id
        def destroy
          authorize @mapping
          @mapping.destroy
          redirect_to edit_web_accounting_integration_path(@integration),
                      notice: "Mapping removed."
        end

        private

        def set_integration
          @integration = AccountingIntegration
                           .where(organization: current_organization)
                           .find(params[:integration_id])
        end

        def set_mapping
          @mapping = @integration.accounting_mappings.find(params[:id])
        end

        def mapping_params
          params.require(:accounting_mapping).permit(:mapping_key, :mapping_value, :notes)
        end
      end
    end
  end
end
