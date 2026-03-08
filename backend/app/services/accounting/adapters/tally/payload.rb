# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Immutable value object that represents a Tally-provider push job.
      #
      # A Payload is constructed by Tally::Adapter#export_master /
      # #export_voucher and stored (as #to_h) in AccountingSyncRecord#payload_json
      # before being handed to the sync worker.
      #
      # Fields
      # ------
      # provider        — always "tally"
      # export_kind     — :master or :voucher
      # entity_type     — canonical class name string, e.g. "Accounting::Canonical::SalesVoucher"
      # canonical_data  — Hash produced by canonical_record.to_h
      # metadata        — Hash with keys: organization_id, branch_id, source_id,
      #                   source_type, event_type, entity_version, synced_at
      # duplicate_key   — deterministic string for idempotency checks
      # filename_hint   — optional string prefix for batch XML export filenames
      # batchable       — Boolean; true when this payload may be queued for bulk export
      class Payload
        PROVIDER = Constants::PROVIDER_NAME

        EXPORT_KINDS = %i[master voucher].freeze

        attr_reader :provider,
                    :export_kind,
                    :entity_type,
                    :canonical_data,
                    :metadata,
                    :duplicate_key,
                    :filename_hint,
                    :batchable

        # @param export_kind     [Symbol]  :master or :voucher
        # @param entity_type     [String]  canonical PORO class name
        # @param canonical_data  [Hash]    canonical_record.to_h output
        # @param metadata        [Hash]    context hash from the adapter
        # @param duplicate_key   [String]  idempotency key
        # @param filename_hint   [String, nil]
        # @param batchable       [Boolean]
        def initialize(
          export_kind:,
          entity_type:,
          canonical_data:,
          metadata: {},
          duplicate_key: nil,
          filename_hint: nil,
          batchable: false
        )
          raise ArgumentError, "export_kind must be :master or :voucher" unless EXPORT_KINDS.include?(export_kind)

          @provider      = PROVIDER
          @export_kind   = export_kind
          @entity_type   = entity_type.to_s
          @canonical_data = canonical_data.is_a?(Hash) ? canonical_data : canonical_data.to_h
          @metadata      = metadata.is_a?(Hash) ? metadata : {}
          @duplicate_key = duplicate_key
          @filename_hint  = filename_hint
          @batchable     = !!batchable

          freeze
        end

        # -----------------------------------------------------------------------
        # Capability predicates
        # -----------------------------------------------------------------------

        def master?
          export_kind == :master
        end

        def voucher?
          export_kind == :voucher
        end

        def batchable?
          batchable
        end

        # -----------------------------------------------------------------------
        # Serialisation
        # -----------------------------------------------------------------------

        def to_h
          {
            provider:       provider,
            export_kind:    export_kind.to_s,
            entity_type:    entity_type,
            canonical_data: canonical_data,
            metadata:       metadata,
            duplicate_key:  duplicate_key,
            filename_hint:  filename_hint,
            batchable:      batchable
          }
        end

        alias as_json to_h

        def to_json(*args)
          to_h.to_json(*args)
        end

        # -----------------------------------------------------------------------
        # Reconstruction from persisted hash
        # -----------------------------------------------------------------------

        # Re-inflate a Payload from a stored payload_json hash.
        #
        # @param hash [Hash] — as written by #to_h
        # @return [Payload]
        def self.from_h(hash)
          h = hash.transform_keys(&:to_s)
          new(
            export_kind:    h["export_kind"].to_sym,
            entity_type:    h["entity_type"],
            canonical_data: h["canonical_data"] || {},
            metadata:       h["metadata"] || {},
            duplicate_key:  h["duplicate_key"],
            filename_hint:  h["filename_hint"],
            batchable:      h["batchable"]
          )
        end
      end
    end
  end
end
