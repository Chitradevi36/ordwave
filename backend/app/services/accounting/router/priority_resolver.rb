# frozen_string_literal: true

module Accounting
  module Router
    # Resolves the processing priority for an AccountingSyncRecord.
    #
    # Priority rules (Phase 1):
    #   :high   — invoice issued/partially_paid, payment recorded, credit note issued
    #   :medium — purchase invoice, any financial posting with unknown event type
    #   :low    — master data sync (retailer, supplier, product)
    #
    # Priorities are stored as strings in accounting_sync_records.priority.
    # The sync worker uses them for polling order (high first).
    module PriorityResolver
      module_function

      HIGH_EVENT_TYPES = %w[
        invoice_issued
        invoice_posted
        payment_recorded
        payment_created
        credit_note_issued
        credit_note_posted
      ].freeze

      MEDIUM_EVENT_TYPES = %w[
        purchase_invoice_posted
        purchase_invoice_created
        invoice_updated
        payment_updated
      ].freeze

      LOW_ENTITY_CLASSES = %w[
        customer retailer supplier vendor product stockitem
      ].freeze

      # @param entity     [Object]
      # @param event_type [String]
      # @return [String]  "high", "medium", or "low"
      def call(entity:, event_type:)
        et = event_type.to_s.downcase

        return "high"   if HIGH_EVENT_TYPES.include?(et)
        return "medium" if MEDIUM_EVENT_TYPES.include?(et)

        # Fall back to entity class name heuristic.
        klass = entity.class.name.to_s.downcase
        return "low" if LOW_ENTITY_CLASSES.any? { |c| klass.include?(c) }

        "medium"
      end
    end
  end
end
