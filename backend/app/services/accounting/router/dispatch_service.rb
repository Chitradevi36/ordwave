# frozen_string_literal: true

module Accounting
  module Router
    # Orchestrates routing of an OMS entity to the accounting sync pipeline.
    #
    # Flow:
    #   1. Resolve the active accounting integration for the entity's org.
    #   2. Return :no_integration if none is found (no-op, not an error).
    #   3. Delegate sync record creation to Sync::CreateSyncRecordService.
    #   4. Return a DispatchResult describing the outcome.
    #
    # DispatchService is the only caller of Sync::CreateSyncRecordService
    # from the router layer.  Jobs and batch services bypass it.
    class DispatchService
      # @param entity     [Object]        any OMS ActiveRecord entity
      # @param event_type [String]        e.g. "invoice_issued", "payment_recorded"
      # @param provider   [String, nil]   optional provider filter
      def initialize(entity:, event_type:, provider: nil)
        @entity     = entity
        @event_type = event_type.to_s
        @provider   = provider
      end

      # @return [Accounting::Result::DispatchResult]
      def call
        integration = resolve_integration
        return no_integration_result if integration.nil?

        create_result = Accounting::Sync::CreateSyncRecordService.new(
          entity:      @entity,
          integration: integration,
          event_type:  @event_type,
          provider:    integration.provider
        ).call

        build_dispatch_result(create_result)
      rescue IntegrationResolver::MissingOrganizationError => e
        error_result(e.message)
      rescue Router::MapperResolver::NoMapperFoundError => e
        # Entity type is not mapped — skip silently with :skipped status.
        # This keeps the trigger callbacks safe from crashing on non-financial entities.
        skipped_result(e.message)
      rescue => e
        Rails.logger.error("[Accounting::DispatchService] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        error_result(e.message)
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      def resolve_integration
        IntegrationResolver.new(@entity, provider: @provider).call
      end

      def build_dispatch_result(create_result)
        case create_result.status
        when :created
          Accounting::Result::DispatchResult.new(
            status:      :enqueued,
            sync_record: create_result.sync_record,
            message:     "Sync record created and job enqueued"
          )
        when :duplicate
          Accounting::Result::DispatchResult.new(
            status:      :duplicate,
            sync_record: create_result.sync_record,
            message:     "Duplicate sync record — already enqueued or completed"
          )
        else
          Accounting::Result::DispatchResult.new(
            status:  :error,
            message: create_result.message || "CreateSyncRecordService returned unexpected status"
          )
        end
      end

      def no_integration_result
        Accounting::Result::DispatchResult.new(
          status:  :no_integration,
          message: "No active accounting integration for this organization"
        )
      end

      def skipped_result(msg)
        Accounting::Result::DispatchResult.new(status: :skipped, message: msg)
      end

      def error_result(msg)
        Accounting::Result::DispatchResult.new(status: :error, message: msg)
      end
    end
  end
end
