# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Low-level XML rendering helpers, tag-name constants, and formatting
      # utilities shared by all Tally XML builder classes.
      #
      # All Nokogiri::XML::Builder interactions should be trivially wrappable
      # around these helpers so that tag-name changes (common during Tally
      # calibration) live in exactly one place.
      module XmlHelper
        # -----------------------------------------------------------------------
        # Outer envelope / request constants
        # -----------------------------------------------------------------------

        TALLY_REQUEST_IMPORT = "Import Data"
        TALLY_REQUEST_EXPORT = "Export Data"

        REPORT_ALL_MASTERS = "All Masters"
        REPORT_VOUCHERS    = "Vouchers"

        XMLNS_UDF = "TallyUDF"

        # ACTION attribute values used on master/voucher elements
        ACTION_CREATE = "Create"
        ACTION_ALTER  = "Alter"
        ACTION_DELETE = "Delete"

        # -----------------------------------------------------------------------
        # Common Tally boolean strings
        # -----------------------------------------------------------------------

        TALLY_YES = "Yes"
        TALLY_NO  = "No"

        # -----------------------------------------------------------------------
        # Default fallback ledger / group names
        # (override at the builder level via ledger_mapping injection)
        # -----------------------------------------------------------------------

        FALLBACK_LEDGER_NAMES = {
          "sales"         => "Sales",
          "purchase"      => "Purchase",
          "round_off"     => "Round Off",
          "cgst"          => "CGST",
          "sgst"          => "SGST",
          "igst"          => "IGST",
          "tds"           => "TDS",
          "bank"          => "Bank",
          "cash"          => "Cash"
        }.freeze

        # -----------------------------------------------------------------------
        # Date helpers
        # NOTE: Tally Prime expects dates in YYYYMMDD with no separators.
        # Calibrate this if your Tally version differs.
        # -----------------------------------------------------------------------

        # @param value [Date, Time, String, nil]
        # @return [String] e.g. "20260301"
        def format_date(value)
          return "" if value.nil?

          case value
          when Date, Time, DateTime
            value.strftime(Constants::DATE_FORMAT)
          when String
            parsed = Date.parse(value) rescue nil
            parsed ? parsed.strftime(Constants::DATE_FORMAT) : value.to_s
          else
            value.to_s
          end
        end

        # -----------------------------------------------------------------------
        # Amount helpers
        # -----------------------------------------------------------------------

        # Returns a BigDecimal-safe, non-scientific-notation string.
        # Tally expects plain decimal strings such as "1250.50".
        #
        # @param value [Numeric, String, nil]
        # @return [String]
        def format_amount(value)
          return "0.00" if value.nil?

          bd = BigDecimal(value.to_s)
          bd.to_s("F").sub(/\.?0+$/, "").then do |s|
            s.include?(".") ? s : "#{s}.00"
          end
        rescue ArgumentError, TypeError
          "0.00"
        end

        # Same as format_amount but negates the value.
        # Useful for Cr-side ledger entries where Tally stores negative amounts.
        #
        # @param value [Numeric, String, nil]
        # @return [String]
        def format_amount_negative(value)
          return "0.00" if value.nil?

          bd = BigDecimal(value.to_s)
          (-bd).to_s("F").sub(/\.?0+$/, "").then do |s|
            s.include?(".") ? s : "#{s}.00"
          end
        rescue ArgumentError, TypeError
          "0.00"
        end

        # -----------------------------------------------------------------------
        # String / text helpers
        # -----------------------------------------------------------------------

        # Returns value.to_s.strip or "" if blank.
        def present_string(value)
          value.to_s.strip
        end

        # Returns value.to_s.strip or fallback if blank.
        def text_or_blank(value, fallback: "")
          s = value.to_s.strip
          s.empty? ? fallback : s
        end

        # Strips characters that can break Tally XML parsing.
        # Tally is sensitive to special characters in NAME attributes.
        def sanitize_name(value)
          value.to_s.strip.gsub(/[&<>"']/, "").squeeze(" ")
        end

        # Convert Ruby boolean to Tally "Yes"/"No" string.
        def boolean_to_tally(value)
          value ? TALLY_YES : TALLY_NO
        end

        # -----------------------------------------------------------------------
        # Nokogiri builder helpers
        # -----------------------------------------------------------------------

        # Appends a simple text node to an xml builder context.
        # Skips the node entirely when value is nil or blank (unless allow_blank: true).
        #
        # Usage:
        #   add_simple_node(xml, "PARTYLEDGERNAME", ledger_name)
        #
        # @param xml   [Nokogiri::XML::Builder]
        # @param name  [String] tag name
        # @param value [Object]
        def add_simple_node(xml, name, value, allow_blank: false)
          str = present_string(value)
          return if str.empty? && !allow_blank

          xml.send(name, str)
        end

        # Appends address lines under an ADDRESS.LIST node.
        # Tally expects one <ADDRESS> child per non-blank line.
        #
        # @param xml   [Nokogiri::XML::Builder]
        # @param lines [Array<String>]
        def add_address_list_node(xml, lines)
          clean = Array(lines).map { |l| present_string(l) }.reject(&:empty?)
          return if clean.empty?

          xml.send(:"ADDRESS.LIST", TYPE: "String") do
            clean.each { |line| xml.ADDRESS(line) }
          end
        end

        # Looks up a ledger name from the provided mapping; falls back to
        # FALLBACK_LEDGER_NAMES; falls back to the raw key if neither resolves.
        #
        # @param key     [String] e.g. "cgst", "sales"
        # @param mapping [Hash]   optional override mapping
        # @return [String]
        def resolve_ledger_name(key, mapping = {})
          k = key.to_s.downcase
          mapping[k] || mapping[key] || FALLBACK_LEDGER_NAMES[k] || key.to_s
        end
      end
    end
  end
end
