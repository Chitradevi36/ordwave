# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Combines multiple canonical entities (and/or Tally::Payload objects)
      # into one or two Tally XML documents ready for batch export.
      #
      # Usage:
      #   xml = BatchExportBuilder.call(
      #     entities: [ledger, stock_item, sales_voucher, receipt],
      #     company_name: "Acme Distributors",
      #     ledger_mapping: { "sales" => "Wholesale Sales" }
      #   )
      #
      # Returns a Hash:
      #   {
      #     masters: "<ENVELOPE>...</ENVELOPE>" or nil,
      #     vouchers: "<ENVELOPE>...</ENVELOPE>" or nil
      #   }
      #
      # Masters (ledgers, stock items) are exported in one envelope with
      # REPORTNAME "All Masters".  Vouchers are exported in a separate envelope
      # with REPORTNAME "Vouchers".  This split follows Tally's recommended
      # import sequence: always import masters before vouchers.
      #
      # Unsupported entity types raise Accounting::Adapters::UnsupportedEntityError.
      class BatchExportBuilder
        include XmlHelper

        # Canonical class → builder class mapping.
        # Add new entries here when extending Phase 2 support.
        BUILDER_REGISTRY = {
          Accounting::Canonical::Ledger             => LedgerXmlBuilder,
          Accounting::Canonical::StockItem          => StockItemXmlBuilder,
          Accounting::Canonical::SalesVoucher       => SalesVoucherXmlBuilder,
          Accounting::Canonical::ReceiptVoucher     => ReceiptVoucherXmlBuilder,
          Accounting::Canonical::CreditNoteVoucher  => CreditNoteXmlBuilder,
          Accounting::Canonical::PurchaseVoucher    => PurchaseVoucherXmlBuilder
        }.freeze

        MASTER_CANONICAL_TYPES = [
          Accounting::Canonical::Ledger,
          Accounting::Canonical::StockItem
        ].freeze

        VOUCHER_CANONICAL_TYPES = [
          Accounting::Canonical::SalesVoucher,
          Accounting::Canonical::ReceiptVoucher,
          Accounting::Canonical::CreditNoteVoucher,
          Accounting::Canonical::PurchaseVoucher
        ].freeze

        # @param entities       [Array]  canonical POROs or Tally::Payload objects
        # @param company_name   [String, nil]
        # @param ledger_mapping [Hash]   optional ledger name overrides
        def initialize(entities:, company_name: nil, ledger_mapping: {})
          @entities       = Array(entities)
          @company_name   = company_name.to_s.strip.presence
          @ledger_mapping = ledger_mapping || {}
        end

        # Class-level entry point.
        #
        # @return [Hash] { masters: String|nil, vouchers: String|nil }
        def self.call(entities:, company_name: nil, ledger_mapping: {})
          new(entities: entities, company_name: company_name, ledger_mapping: ledger_mapping).call
        end

        # Instance entry point.
        #
        # @return [Hash] { masters: String|nil, vouchers: String|nil }
        def call
          master_messages  = master_entities.map  { |e| build_message(e) }
          voucher_messages = voucher_entities.map { |e| build_message(e) }

          envelope = EnvelopeBuilder.new(company_name: @company_name)

          {
            masters:  master_messages.any?  ? envelope.build_collection(report_name: XmlHelper::REPORT_ALL_MASTERS, messages: master_messages)  : nil,
            vouchers: voucher_messages.any? ? envelope.build_collection(report_name: XmlHelper::REPORT_VOUCHERS,    messages: voucher_messages) : nil
          }
        end

        # -----------------------------------------------------------------------
        # Sub-collections (accessible for inspection/testing)
        # -----------------------------------------------------------------------

        # Entities unwrapped from any Payload wrappers, keeping stable order.
        def normalized_entities
          @normalized_entities ||= @entities.map { |e| normalize(e) }
        end

        def master_entities
          @master_entities ||= @entities.select { |e| master?(normalize(e)) }
        end

        def voucher_entities
          @voucher_entities ||= @entities.select { |e| voucher?(normalize(e)) }
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        # Returns the builder class for the canonical entity.
        # Raises UnsupportedEntityError for unknown types.
        #
        # @param entity [Object] canonical PORO or Hash
        # @return [Class < BaseXmlBuilder]
        def builder_for(entity)
          klass = entity.class

          # Direct class match first.
          builder_klass = BUILDER_REGISTRY[klass]
          return builder_klass if builder_klass

          # Inheritance-aware lookup (e.g. subclasses of canonical types).
          builder_klass = BUILDER_REGISTRY.find { |k, _| klass <= k }&.last
          return builder_klass if builder_klass

          # Hash-based canonical data from a payload — inspect the entity_type hint.
          if entity.is_a?(Hash)
            type_hint = entity[:entity_type] || entity["entity_type"]
            if type_hint.present?
              resolved_klass = Object.const_get(type_hint) rescue nil
              if resolved_klass
                return BUILDER_REGISTRY[resolved_klass] ||
                       BUILDER_REGISTRY.find { |k, _| resolved_klass <= k }&.last
              end
            end
          end

          raise UnsupportedEntityError.new(
            Constants::PROVIDER_NAME,
            klass.name || entity.inspect
          )
        end

        # Build a single TALLYMESSAGE XML fragment string for one entity.
        #
        # @param entity [Object] raw entity from @entities (may be a Payload)
        # @return [String] TALLYMESSAGE XML fragment
        def build_message(entity)
          canonical = normalize(entity)
          klass     = builder_for(canonical)

          klass.new(
            canonical,
            ledger_mapping: @ledger_mapping,
            company_name:   @company_name
          ).call
        end

        # Resolves the canonical entity from a Payload or returns it unchanged.
        def normalize(entity)
          return entity unless entity.is_a?(Tally::Payload)

          # Unwrap canonical_data and annotate with entity_type for builder lookup.
          data = entity.canonical_data.merge("entity_type" => entity.entity_type)
          data
        end

        def master?(entity)
          BUILDER_REGISTRY.each do |canonical_klass, builder_klass|
            return true if entity.is_a?(canonical_klass) && MASTER_CANONICAL_TYPES.any? { |m| canonical_klass <= m }
          end

          # Hash form from a payload
          if entity.is_a?(Hash)
            type_hint = entity[:entity_type] || entity["entity_type"]
            if type_hint.present?
              resolved = Object.const_get(type_hint) rescue nil
              return MASTER_CANONICAL_TYPES.any? { |m| resolved <= m } if resolved
            end
          end

          false
        end

        def voucher?(entity)
          BUILDER_REGISTRY.each do |canonical_klass, _|
            return true if entity.is_a?(canonical_klass) && VOUCHER_CANONICAL_TYPES.any? { |v| canonical_klass <= v }
          end

          if entity.is_a?(Hash)
            type_hint = entity[:entity_type] || entity["entity_type"]
            if type_hint.present?
              resolved = Object.const_get(type_hint) rescue nil
              return VOUCHER_CANONICAL_TYPES.any? { |v| resolved <= v } if resolved
            end
          end

          false
        end
      end
    end
  end
end
