# frozen_string_literal: true

require "nokogiri"
require "bigdecimal"

module Accounting
  module Adapters
    module Tally
      # Abstract base class for all Tally entity-specific XML builders.
      #
      # Responsibilities:
      # - Accept a canonical accounting PORO or a Tally::Payload object
      # - Expose #call → returns a TALLYMESSAGE XML fragment string
      # - Expose #build_document → returns a fully-wrapped XML string
      # - Provide shared formatting, validation, and Nokogiri helpers
      #
      # Subclasses must implement:
      #   #build_message(xml)  — receives a Nokogiri::XML::Builder context
      #                          scoped inside a TALLYMESSAGE element.
      #                          Should build the entity-specific child nodes.
      #   #export_kind         — :master or :voucher (used for envelope wrapping)
      #   #report_name         — Tally REPORTNAME string
      #
      # Optional configuration injection:
      #   ledger_mapping: Hash  — override fallback ledger names (keys are
      #                           "sales", "purchase", "cgst", "sgst", etc.)
      #   company_name:  String — forwarded to EnvelopeBuilder
      class BaseXmlBuilder
        include XmlHelper

        # @param entity        [Canonical PORO or Tally::Payload]
        # @param ledger_mapping [Hash]   optional ledger name overrides
        # @param company_name  [String]  optional Tally company name for full docs
        def initialize(entity, ledger_mapping: {}, company_name: nil)
          @entity        = canonical_entity(entity)
          @ledger_mapping = ledger_mapping || {}
          @company_name  = company_name.to_s.strip.presence
        end

        # -----------------------------------------------------------------------
        # Public interface
        # -----------------------------------------------------------------------

        # Returns just the inner TALLYMESSAGE XML fragment string.
        # This is what the batch builder collects before wrapping in an envelope.
        #
        # @return [String]
        def call
          fragment_builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
            xml.TALLYMESSAGE("xmlns:UDF" => XmlHelper::XMLNS_UDF) do
              build_message(xml)
            end
          end

          # Return just the root node as an XML string (no <?xml?> declaration)
          fragment_builder.doc.root.to_xml
        end

        # Returns a fully-wrapped, standalone XML document ready to POST to Tally.
        # Combines #call with EnvelopeBuilder.
        #
        # @return [String]
        def build_document
          EnvelopeBuilder
            .new(company_name: @company_name)
            .build_single(report_name: report_name, message_xml: call)
        end

        # -----------------------------------------------------------------------
        # Template methods — must be overridden by subclasses
        # -----------------------------------------------------------------------

        # @param xml [Nokogiri::XML::Builder] scoped inside TALLYMESSAGE
        def build_message(xml)
          raise NotImplementedError, "#{self.class}#build_message must be implemented"
        end

        # @return [:master, :voucher]
        def export_kind
          raise NotImplementedError, "#{self.class}#export_kind must be implemented"
        end

        # @return [String] e.g. XmlHelper::REPORT_ALL_MASTERS
        def report_name
          raise NotImplementedError, "#{self.class}#report_name must be implemented"
        end

        # -----------------------------------------------------------------------
        # Shared helpers available to all subclasses
        # -----------------------------------------------------------------------

        protected

        attr_reader :entity, :ledger_mapping, :company_name

        # Resolves the canonical PORO from either a direct PORO or a Payload.
        #
        # @param input [Canonical PORO or Tally::Payload]
        # @return [Object] canonical PORO
        def canonical_entity(input)
          return input unless input.is_a?(Tally::Payload)

          # Reconstruct a plain Hash-like struct from the payload's canonical_data.
          # Subclasses that accept payloads should call this and work with the hash.
          input.canonical_data
        end

        # Returns a Hash regardless of whether entity is a PORO or a Hash.
        #
        # @return [Hash]
        def entity_hash
          return @entity if @entity.is_a?(Hash)

          @entity.respond_to?(:to_h) ? @entity.to_h : {}
        end

        # Safely reads a field from the entity (PORO or Hash).
        #
        # @param field [Symbol, String]
        # @return [Object, nil]
        def field(field_name)
          sym = field_name.to_sym
          str = field_name.to_s

          if @entity.is_a?(Hash)
            @entity[sym] || @entity[str]
          elsif @entity.respond_to?(sym)
            @entity.public_send(sym)
          end
        end

        # Resolves a ledger name through the injected mapping, then falls back
        # to XmlHelper::FALLBACK_LEDGER_NAMES.
        def resolve_name(key)
          resolve_ledger_name(key, @ledger_mapping)
        end

        # Appends tax ledger ALLLEDGERENTRIES.LIST nodes for an array of
        # Canonical::TaxEntry (or equivalent hashes).
        #
        # In Tally's sales/purchase voucher model, each tax component (CGST,
        # SGST, IGST) is a separate ledger entry on the Cr side.
        #
        # Calibration note:
        #   ISDEEMEDPOSITIVE for tax credits = "No" in most Tally versions.
        #   Amount sign: Cr (tax) entries use negative amounts.
        #   Validate this against your live Tally setup during integration testing.
        #
        # @param xml         [Nokogiri::XML::Builder]
        # @param tax_entries [Array<TaxEntry or Hash>]
        def add_tax_ledger_entries(xml, tax_entries)
          Array(tax_entries).each do |entry|
            ledger_kind = read_from(entry, :ledger_kind) || read_from(entry, :tax_type) || ""
            amount      = read_from(entry, :amount)
            label       = read_from(entry, :label)
            ledger_name = label.presence || resolve_name(ledger_kind)

            next if ledger_name.blank? || amount.nil?

            xml.send(:"ALLLEDGERENTRIES.LIST") do
              xml.LEDGERNAME(sanitize_name(ledger_name))
              # Tax entries are Cr-side: ISDEEMEDPOSITIVE=No, amount stored negative
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount_negative(amount))
              # GST class detail — calibrate tag names if needed
              xml.send(:"CATEGORYALLOCATIONS.LIST") do
                xml.CATEGORY(ledger_name)
                xml.ISDEEMEDPOSITIVE(TALLY_NO)
                xml.AMOUNT(format_amount_negative(amount))
              end
            end
          end
        end

        # Appends address lines using Tally's ADDRESS.LIST convention.
        # Accepts either a Canonical::Address PORO or a plain Hash.
        #
        # @param xml     [Nokogiri::XML::Builder]
        # @param address [Canonical::Address, Hash, nil]
        def add_address_nodes(xml, address)
          return if address.nil?

          lines = if address.is_a?(Hash)
                    [
                      address[:line1] || address["line1"],
                      address[:line2] || address["line2"],
                      address[:city]  || address["city"],
                      address[:state] || address["state"],
                      "#{address[:postal_code] || address['postal_code']} #{address[:country] || address['country']}"
                    ]
                  elsif address.respond_to?(:to_address_lines)
                    address.to_address_lines
                  else
                    [
                      address.try(:line1),
                      address.try(:line2),
                      address.try(:city),
                      address.try(:state),
                      [address.try(:postal_code), address.try(:country)].compact.join(" ")
                    ]
                  end

          add_address_list_node(xml, lines)
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        # Read a field from either a PORO or a Hash.
        def read_from(obj, key)
          sym = key.to_sym
          str = key.to_s
          if obj.is_a?(Hash)
            obj[sym] || obj[str]
          elsif obj.respond_to?(sym)
            obj.public_send(sym)
          end
        end
      end
    end
  end
end
