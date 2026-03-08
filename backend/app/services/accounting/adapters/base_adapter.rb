# frozen_string_literal: true

module Accounting
  module Adapters
    # Abstract base class that every accounting provider adapter must subclass.
    #
    # Subclass contract
    # -----------------
    # Mandatory overrides (raise NotImplementedError by default):
    #   validate_config!           — raise InvalidConfigurationError if the integration
    #                                config_json is insufficient for this provider.
    #   supported_master_types     — return Array of canonical PORO *classes* this adapter
    #                                can export as master data (e.g. Ledger, StockItem).
    #   supported_voucher_types    — return Array of canonical PORO *classes* this adapter
    #                                can export as vouchers.
    #   export_master(canonical)   — accept a canonical master PORO; return a provider
    #                                Payload object ready for the sync worker.
    #   export_voucher(canonical)  — accept a canonical voucher PORO; return a provider
    #                                Payload object ready for the sync worker.
    #   build_payload(sync_record:)— reconstruct a Payload from a persisted
    #                                AccountingSyncRecord (used for retries/replays).
    #   duplicate_check_key(payload) — return a deterministic string key used by the
    #                                  sync worker to detect duplicate submissions.
    #
    # Optional overrides:
    #   supports_realtime?         — return true if the adapter can push in real-time
    #                                (default: false).
    #   supports_batch_export?     — return true if batch XML/CSV export is supported
    #                                (default: false).
    class BaseAdapter
      attr_reader :integration

      # @param integration [AccountingIntegration]
      def initialize(integration)
        @integration = integration
      end

      # -----------------------------------------------------------------------
      # Capability queries
      # -----------------------------------------------------------------------

      def supports_realtime?
        false
      end

      def supports_batch_export?
        false
      end

      # Returns :master, :voucher, or nil for unknown entity types.
      #
      # @param canonical [Object] a canonical PORO instance
      # @return [Symbol, nil]
      def export_kind_for(canonical)
        klass = canonical.is_a?(Class) ? canonical : canonical.class
        return :master  if supported_master_types.any? { |t| klass <= t }
        return :voucher if supported_voucher_types.any? { |t| klass <= t }

        nil
      end

      # Returns true when the adapter can handle the given canonical entity.
      #
      # @param canonical [Object]
      def supports_entity?(canonical)
        !export_kind_for(canonical).nil?
      end

      # -----------------------------------------------------------------------
      # Abstract interface — must be implemented by subclasses
      # -----------------------------------------------------------------------

      def validate_config!
        raise NotImplementedError, "#{self.class}#validate_config! must be implemented"
      end

      def supported_master_types
        raise NotImplementedError, "#{self.class}#supported_master_types must be implemented"
      end

      def supported_voucher_types
        raise NotImplementedError, "#{self.class}#supported_voucher_types must be implemented"
      end

      def export_master(canonical)
        raise NotImplementedError, "#{self.class}#export_master must be implemented"
      end

      def export_voucher(canonical)
        raise NotImplementedError, "#{self.class}#export_voucher must be implemented"
      end

      def build_payload(sync_record:)
        raise NotImplementedError, "#{self.class}#build_payload must be implemented"
      end

      def duplicate_check_key(payload)
        raise NotImplementedError, "#{self.class}#duplicate_check_key must be implemented"
      end

      # -----------------------------------------------------------------------
      # High-level dispatch helper (optional use by callers)
      # -----------------------------------------------------------------------

      # Routes a canonical record to export_master or export_voucher based on
      # its type.  Raises UnsupportedEntityError for unrecognised types.
      #
      # @param canonical [Object]
      # @return [Object] provider-specific Payload
      def export(canonical)
        kind = export_kind_for(canonical)
        raise UnsupportedEntityError.new(provider_name, canonical) unless kind

        kind == :master ? export_master(canonical) : export_voucher(canonical)
      end

      # -----------------------------------------------------------------------
      # Helpers
      # -----------------------------------------------------------------------

      private

      def provider_name
        integration.provider.to_s
      end
    end
  end
end
