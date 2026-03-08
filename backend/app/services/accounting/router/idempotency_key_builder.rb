# frozen_string_literal: true

module Accounting
  module Router
    # Builds a deterministic idempotency key for an AccountingSyncRecord.
    #
    # Format:
    #   "{provider}:{EntityClass}:{entity_id}:{entity_version}:{event_type}"
    #
    # This key is stored in accounting_sync_records.idempotency_key and
    # backed by a DB unique index.  Any two sync attempts with identical
    # provider + entity + version + event produce the same key, ensuring
    # the append-only sync record table never creates true duplicates.
    #
    # Key components:
    #   provider       — "tally", or future provider slug
    #   entity class   — demodulized class name, e.g. "SalesInvoice"
    #   entity_id      — numeric PK
    #   entity_version — from EntityVersionBuilder (changes with state)
    #   event_type     — e.g. "invoice_issued", "payment_recorded"
    module IdempotencyKeyBuilder
      module_function

      MAX_LENGTH = 255

      # @param provider       [String]
      # @param entity         [Object]
      # @param event_type     [String]
      # @param entity_version [String]
      # @return [String]
      def call(provider:, entity:, event_type:, entity_version:)
        parts = [
          provider.to_s.downcase,
          entity.class.name.demodulize,
          entity.id.to_s,
          entity_version.to_s,
          event_type.to_s
        ]

        key = parts.join(":")

        # Truncate to DB column limit using SHA1 suffix to keep uniqueness.
        if key.length > MAX_LENGTH
          digest = Digest::SHA1.hexdigest(key)[0, 12]
          key    = "#{key[0, MAX_LENGTH - 13]}:#{digest}"
        end

        key
      end
    end
  end
end
