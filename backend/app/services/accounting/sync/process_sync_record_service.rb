# frozen_string_literal: true

module Accounting
  module Sync
    # Processes a single AccountingSyncRecord through the provider adapter.
    #
    # Phase 1 completion contract:
    #   A sync record is marked "completed" when the provider-ready XML payload
    #   has been successfully generated and the output summary is stored in
    #   response_body.  Direct HTTP delivery to Tally is deferred to Phase 2.
    #
    # The service reads everything it needs from sync_record.payload_json so it
    # does NOT re-query the source OMS entity.  This preserves the audit trail
    # and makes replays safe.
    class ProcessSyncRecordService
      # Maps canonical type name → Tally XML builder class.
      # Add new entries here when extending Phase 2.
      XML_BUILDER_REGISTRY = {
        "Accounting::Canonical::Ledger"            => -> { Accounting::Adapters::Tally::LedgerXmlBuilder },
        "Accounting::Canonical::StockItem"         => -> { Accounting::Adapters::Tally::StockItemXmlBuilder },
        "Accounting::Canonical::SalesVoucher"      => -> { Accounting::Adapters::Tally::SalesVoucherXmlBuilder },
        "Accounting::Canonical::ReceiptVoucher"    => -> { Accounting::Adapters::Tally::ReceiptVoucherXmlBuilder },
        "Accounting::Canonical::CreditNoteVoucher" => -> { Accounting::Adapters::Tally::CreditNoteXmlBuilder },
        "Accounting::Canonical::PurchaseVoucher"   => -> { Accounting::Adapters::Tally::PurchaseVoucherXmlBuilder }
      }.freeze

      # @param sync_record [AccountingSyncRecord]
      def initialize(sync_record)
        @sync_record = sync_record
      end

      # @return [Boolean] true on success
      def call
        # Reload and lock in one operation to prevent concurrent processing.
        @sync_record.with_lock do
          if skip_processing?
            Rails.logger.debug("[ProcessSyncRecordService] Skipping #{@sync_record.id} (status=#{@sync_record.status})")
            return false
          end

          do_process
        end

        true
      rescue => e
        handle_unexpected_error(e)
        false
      end

      # -----------------------------------------------------------------------
      private
      # -----------------------------------------------------------------------

      def skip_processing?
        @sync_record.completed? || @sync_record.processing?
      end

      def do_process
        mark_processing!

        adpt      = adapter
        adpt.validate_config!

        output    = build_provider_output(adpt)

        # Phase 2: Check sync mode - realtime agent or batch export
        if @sync_record.accounting_integration.sync_mode_realtime_agent?
          # Realtime agent mode: store XML and mark as pending for agent pickup
          @sync_record.update_columns(
            status:        "pending",
            response_body: output[:xml], # Store full XML for agent to consume
            error_message: nil
          )

          Rails.logger.info(
            "[ProcessSyncRecordService] sync_record##{@sync_record.id} ready for agent pickup"
          )
        else
          # Batch export mode: mark as completed with summary
          summary = output_summary_for_storage(output)

          @sync_record.update_columns(
            status:        "completed",
            response_body: summary,
            error_message: nil
          )

          Rails.logger.info("[ProcessSyncRecordService] sync_record##{@sync_record.id} completed")
        end
      rescue Accounting::Adapters::InvalidConfigurationError => e
        finalize_failure(e, retryable: false)
      rescue => e
        finalize_failure(e, retryable: true)
      end

      def mark_processing!
        @sync_record.update_columns(
          status:           "processing",
          last_attempted_at: Time.current
        )
      end

      # -----------------------------------------------------------------------
      # Adapter
      # -----------------------------------------------------------------------

      def adapter
        @adapter ||= Accounting::Adapters::Factory.build(@sync_record.accounting_integration)
      end

      # -----------------------------------------------------------------------
      # Payload / XML generation
      # -----------------------------------------------------------------------

      # Resolves the canonical type from payload snapshot, instantiates the
      # appropriate XML builder, and returns a hash with the generated XML string.
      #
      # @param adpt [BaseAdapter]
      # @return [Hash] { xml: String, canonical_type: String, entity_type: String, kind: String }
      def build_provider_output(adpt)
        snapshot       = @sync_record.payload_json || {}
        canonical_type = snapshot["canonical_type"].to_s
        canonical_data = snapshot["canonical_data"] || {}
        metadata       = snapshot["metadata"] || {}

        # Build the Tally Payload from stored snapshot.
        # Phase 1: we generate the XML string from the canonical_data hash.
        xml_fragment = generate_xml(canonical_type, canonical_data, adpt)

        {
          xml:            xml_fragment,
          canonical_type: canonical_type,
          entity_type:    @sync_record.entity_type,
          entity_id:      @sync_record.entity_id,
          kind:           export_kind_for_canonical(canonical_type)
        }
      end

      # route to correct XML builder based on canonical type string.
      def generate_xml(canonical_type, canonical_data, adpt)
        builder_klass = xml_builder_for(canonical_type)

        company_name = adpt.respond_to?(:config) ? adpt.config.company_name : nil

        builder_klass
          .new(canonical_data, company_name: company_name)
          .call
      end

      def xml_builder_for(canonical_type)
        entry = XML_BUILDER_REGISTRY[canonical_type]
        raise Accounting::Adapters::UnsupportedEntityError.new(
          @sync_record.provider,
          canonical_type
        ) unless entry

        entry.call
      end

      def export_kind_for_canonical(canonical_type)
        master_types = %w[
          Accounting::Canonical::Ledger
          Accounting::Canonical::StockItem
        ]
        master_types.include?(canonical_type) ? "master" : "voucher"
      end

      # -----------------------------------------------------------------------
      # Response storage
      # -----------------------------------------------------------------------

      # Builds a compact hash stored in response_body for audit/replay.
      def output_summary_for_storage(output)
        {
          provider:       @sync_record.provider,
          canonical_type: output[:canonical_type],
          entity_type:    output[:entity_type],
          entity_id:      output[:entity_id],
          export_kind:    output[:kind],
          xml_length:     output[:xml].to_s.length,
          # Store a trimmed preview of the XML for debugging without blowing up JSONB column.
          xml_preview:    output[:xml].to_s[0, 500],
          generated_at:   Time.current.iso8601,
          phase:          "xml_generated"
        }
      end

      # -----------------------------------------------------------------------
      # Failure handling
      # -----------------------------------------------------------------------

      def finalize_failure(error, retryable: true)
        Rails.logger.error(
          "[ProcessSyncRecordService] sync_record##{@sync_record.id} " \
          "#{error.class}: #{error.message}"
        )

        new_status = final_status_after_failure(retryable: retryable)

        @sync_record.update_columns(
          status:        new_status,
          error_message: "#{error.class}: #{error.message}",
          attempts:      @sync_record.attempts + 1
        )
      end

      # Determine whether the record should be left as "failed" (retry eligible)
      # or "failed" with no more retries.  The retry job polls for eligible
      # records based on attempts vs max_attempts.
      def final_status_after_failure(retryable: true)
        return "failed" unless retryable

        remaining = @sync_record.max_attempts - (@sync_record.attempts + 1)
        remaining > 0 ? "failed" : "failed"
        # Both branch to "failed"; the retry sweeper checks attempts vs max.
        # "retrying" status is set by RetrySyncRecordService when it re-enqueues.
      end

      def handle_unexpected_error(error)
        Rails.logger.error(
          "[ProcessSyncRecordService] Unexpected error for sync_record##{@sync_record.id}: " \
          "#{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}"
        )
        begin
          @sync_record.update_columns(
            status:        "failed",
            error_message: "Unexpected: #{error.class}: #{error.message}"
          )
        rescue => update_error
          Rails.logger.error("[ProcessSyncRecordService] Could not update sync_record: #{update_error.message}")
        end
      end
    end
  end
end
