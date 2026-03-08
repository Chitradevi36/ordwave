# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Phase 1 Tally Prime adapter.
      #
      # Responsibilities
      # ----------------
      # 1. Validates the integration's config_json via Tally::Configuration.
      # 2. Declares which canonical types it supports (Phase 1 scope).
      # 3. Converts canonical POROs → Tally::Payload objects consumed by the
      #    sync worker.
      # 4. Reconstructs payloads from persisted AccountingSyncRecord for
      #    retries and replays.
      # 5. Provides deterministic duplicate-check keys for idempotency.
      #
      # XML generation (the actual HTTP POST to Tally) is intentionally
      # deferred to Phase 2 builder/sender classes; this adapter only produces
      # the serialisable Payload value object.
      class Adapter < BaseAdapter
        include Constants

        # @param integration [AccountingIntegration]
        def initialize(integration)
          super
          @config = Configuration.new(integration)
        end

        # -----------------------------------------------------------------------
        # Configuration validation
        # -----------------------------------------------------------------------

        # @raise [InvalidConfigurationError] when required fields are absent
        def validate_config!
          return if @config.valid_for_phase1?

          raise InvalidConfigurationError.new(
            Constants::PROVIDER_NAME,
            @config.missing_required_fields
          )
        end

        # -----------------------------------------------------------------------
        # Capabilities
        # -----------------------------------------------------------------------

        def supports_realtime?
          @config.sync_mode_realtime_agent?
        end

        def supports_batch_export?
          @config.sync_mode_batch_export?
        end

        # -----------------------------------------------------------------------
        # Supported entity types
        # -----------------------------------------------------------------------

        def supported_master_types
          Constants::SUPPORTED_MASTER_CLASSES
        end

        def supported_voucher_types
          Constants::SUPPORTED_VOUCHER_CLASSES
        end

        # -----------------------------------------------------------------------
        # Export: canonical → Payload
        # -----------------------------------------------------------------------

        # @param canonical [Accounting::Canonical::Ledger, Accounting::Canonical::StockItem]
        # @return [Tally::Payload]
        def export_master(canonical)
          assert_supported!(canonical)

          Payload.new(
            export_kind:    :master,
            entity_type:    canonical.class.name,
            canonical_data: canonical.to_h,
            metadata:       build_tally_metadata(canonical),
            duplicate_key:  master_duplicate_key(canonical),
            filename_hint:  master_filename_hint(canonical),
            batchable:      true
          )
        end

        # @param canonical [Accounting::Canonical::SalesVoucher, ...]
        # @return [Tally::Payload]
        def export_voucher(canonical)
          assert_supported!(canonical)

          Payload.new(
            export_kind:    :voucher,
            entity_type:    canonical.class.name,
            canonical_data: canonical.to_h,
            metadata:       build_tally_metadata(canonical),
            duplicate_key:  voucher_duplicate_key(canonical),
            filename_hint:  voucher_filename_hint(canonical),
            batchable:      supports_batch_export?
          )
        end

        # -----------------------------------------------------------------------
        # Replay: AccountingSyncRecord → Payload
        # -----------------------------------------------------------------------

        # Reconstructs a Payload from the persisted payload_json of a sync
        # record.  Used by the retry/replay worker.
        #
        # @param sync_record [AccountingSyncRecord]
        # @return [Tally::Payload]
        def build_payload(sync_record:)
          raw = sync_record.payload_json
          raise ArgumentError, "sync_record.payload_json is nil" if raw.nil?

          Payload.from_h(raw)
        end

        # -----------------------------------------------------------------------
        # Idempotency key
        # -----------------------------------------------------------------------

        # Returns a deterministic string key from a Payload object.
        #
        # Format:
        #   tally|<entity_type>|<source_id>|<source_type>|<event_type>|<entity_version>
        #
        # @param payload [Tally::Payload]
        # @return [String]
        def duplicate_check_key(payload)
          meta = payload.metadata || {}
          [
            Constants::PROVIDER_NAME,
            payload.entity_type,
            meta["source_id"],
            meta["source_type"],
            meta["event_type"],
            meta["entity_version"]
          ].join("|")
        end

        # -----------------------------------------------------------------------
        # Accessors for downstream use
        # -----------------------------------------------------------------------

        # @return [Tally::Configuration]
        def config
          @config
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        def assert_supported!(canonical)
          return if supports_entity?(canonical)

          raise UnsupportedEntityError.new(Constants::PROVIDER_NAME, canonical)
        end

        # Build the metadata hash that accompanies every Payload.  The canonical
        # POROs carry a #metadata field (from BaseRecord / SalesVoucher etc.)
        # with keys like organization_id, branch_id, source_id, source_type,
        # event_type, entity_version.  We merge them with Tally-specific fields.
        def build_tally_metadata(canonical)
          base = canonical.respond_to?(:metadata) ? (canonical.metadata || {}) : {}
          base.merge(
            "provider"     => Constants::PROVIDER_NAME,
            "company_name" => @config.company_name,
            "synced_at"    => Time.current.iso8601
          )
        end

        # -----------------------------------------------------------------------
        # Duplicate key helpers
        # -----------------------------------------------------------------------

        def master_duplicate_key(canonical)
          name = canonical.respond_to?(:name) ? canonical.name.to_s : ""
          [
            Constants::PROVIDER_NAME,
            canonical.class.name,
            name
          ].join("|")
        end

        def voucher_duplicate_key(canonical)
          ref = voucher_reference(canonical)
          meta = canonical.respond_to?(:metadata) ? (canonical.metadata || {}) : {}
          [
            Constants::PROVIDER_NAME,
            canonical.class.name,
            ref,
            meta["entity_version"]
          ].join("|")
        end

        def voucher_reference(canonical)
          return canonical.voucher_number if canonical.respond_to?(:voucher_number)
          return canonical.reference      if canonical.respond_to?(:reference)

          ""
        end

        # -----------------------------------------------------------------------
        # Filename hint helpers (used in batch XML export mode)
        # -----------------------------------------------------------------------

        def master_filename_hint(canonical)
          short = canonical.class.name.demodulize.underscore
          "tally_master_#{short}"
        end

        def voucher_filename_hint(canonical)
          short = canonical.class.name.demodulize.underscore
          ref   = voucher_reference(canonical).gsub(/[^A-Za-z0-9_\-]/, "_")
          "tally_#{short}_#{ref}"
        end
      end
    end
  end
end
