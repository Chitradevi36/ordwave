# frozen_string_literal: true

module Api
  module V1
    module Accounting
      class MappingsController < BaseController
        before_action :require_organization!
        before_action :set_integration

        # GET /api/v1/accounting/integrations/:integration_id/mappings
        def index
          mappings = policy_scope(AccountingMapping)
                       .where(accounting_integration: @integration)
                       .order(:mapping_key)
          render_success(mappings.map { |m| serialize(m) })
        end

        # POST /api/v1/accounting/integrations/:integration_id/mappings
        def create
          mapping = @integration.accounting_mappings.find_or_initialize_by(
            organization:  current_organization,
            mapping_key:   mapping_params[:mapping_key].to_s.strip.downcase
          )
          authorize mapping
          mapping.mapping_value = mapping_params[:mapping_value]

          if mapping.save
            render_created(serialize(mapping))
          else
            render_errors(mapping.errors.full_messages)
          end
        end

        # PUT /api/v1/accounting/integrations/:integration_id/mappings/:id
        def update
          mapping = @integration.accounting_mappings.find(params[:id])
          authorize mapping

          if mapping.update(mapping_value: mapping_params[:mapping_value])
            render_success(serialize(mapping))
          else
            render_errors(mapping.errors.full_messages)
          end
        end

        # DELETE /api/v1/accounting/integrations/:integration_id/mappings/:id
        def destroy
          mapping = @integration.accounting_mappings.find(params[:id])
          authorize mapping

          mapping.destroy!
          render json: {}, status: :no_content
        end

        private

        def set_integration
          @integration = current_organization.accounting_integrations.find(params[:integration_id])
        end

        def mapping_params
          params.require(:accounting_mapping).permit(:mapping_key, :mapping_value)
        end

        def serialize(mapping)
          {
            id:             mapping.id,
            mapping_key:    mapping.mapping_key,
            mapping_value:  mapping.mapping_value,
            created_at:     mapping.created_at,
            updated_at:     mapping.updated_at
          }
        end
      end
    end
  end
end
