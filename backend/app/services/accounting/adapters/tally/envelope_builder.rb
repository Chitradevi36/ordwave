# frozen_string_literal: true

require "nokogiri"

module Accounting
  module Adapters
    module Tally
      # Builds the outermost Tally XML envelope that wraps one or many import
      # message fragments.
      #
      # All Tally XML import documents share the same outer skeleton:
      #
      #   <ENVELOPE>
      #     <HEADER>
      #       <TALLYREQUEST>Import Data</TALLYREQUEST>
      #     </HEADER>
      #     <BODY>
      #       <IMPORTDATA>
      #         <REQUESTDESC>
      #           <REPORTNAME>All Masters</REPORTNAME>
      #           <STATICVARIABLES>
      #             <SVCURRENTCOMPANY>Company Name</SVCURRENTCOMPANY>
      #           </STATICVARIABLES>
      #         </REQUESTDESC>
      #         <REQUESTDATA>
      #           ...TALLYMESSAGE fragments...
      #         </REQUESTDATA>
      #       </IMPORTDATA>
      #     </BODY>
      #   </ENVELOPE>
      #
      # EnvelopeBuilder is the single place that generates this structure.
      # Entity builders produce only the inner TALLYMESSAGE XML fragment and
      # delegate wrapping to this class.
      #
      # Calibration note:
      #   The REPORTNAME and SVCURRENTCOMPANY values are the most likely nodes
      #   to vary across Tally versions.  Change them here only.
      class EnvelopeBuilder
        include XmlHelper

        # @param company_name [String, nil]  inserted as SVCURRENTCOMPANY; pass nil to omit
        # @param request_type [String]       TALLYREQUEST value (default "Import Data")
        def initialize(company_name: nil, request_type: XmlHelper::TALLY_REQUEST_IMPORT)
          @company_name = company_name.to_s.strip.presence
          @request_type = request_type
        end

        # -----------------------------------------------------------------------
        # Public API
        # -----------------------------------------------------------------------

        # Build a complete envelope for a single TALLYMESSAGE fragment.
        #
        # @param report_name [String]  e.g. XmlHelper::REPORT_ALL_MASTERS
        # @param message_xml [String]  inner XML fragment (the TALLYMESSAGE element)
        # @return [String] full XML document as string
        def build_single(report_name:, message_xml:)
          build_envelope(report_name: report_name, messages: [message_xml])
        end

        # Build a complete envelope wrapping multiple TALLYMESSAGE fragments.
        # Useful when batching many entities into one import request.
        #
        # @param report_name [String]
        # @param messages    [Array<String>]  inner XML fragments
        # @return [String]
        def build_collection(report_name:, messages:)
          build_envelope(report_name: report_name, messages: Array(messages))
        end

        # Convenience wrapper — infers report_name from a predefined entity kind.
        #
        # @param kind     [:master, :voucher]
        # @param messages [Array<String>]
        # @return [String]
        def wrap_import_data(kind:, messages:)
          report_name = kind.to_sym == :master ? XmlHelper::REPORT_ALL_MASTERS : XmlHelper::REPORT_VOUCHERS
          build_collection(report_name: report_name, messages: messages)
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        def build_envelope(report_name:, messages:)
          builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
            xml.ENVELOPE do
              build_header(xml)
              build_body(xml, report_name: report_name, messages: messages)
            end
          end

          builder.to_xml
        end

        def build_header(xml)
          xml.HEADER do
            xml.TALLYREQUEST(@request_type)
          end
        end

        def build_body(xml, report_name:, messages:)
          xml.BODY do
            xml.IMPORTDATA do
              build_request_desc(xml, report_name: report_name)
              build_request_data(xml, messages: messages)
            end
          end
        end

        def build_request_desc(xml, report_name:)
          xml.REQUESTDESC do
            xml.REPORTNAME(report_name)
            build_static_variables(xml)
          end
        end

        def build_static_variables(xml)
          # SVCURRENTCOMPANY targets the active company in Tally.
          # Omitting it uses whichever company is currently open in Tally.
          # Calibrate: some Tally versions use SVCURRENTCOMPANY, others
          # may use SVEXPORTFORMAT or no static variables at all.
          return unless @company_name.present?

          xml.STATICVARIABLES do
            xml.SVCURRENTCOMPANY(@company_name)
          end
        end

        def build_request_data(xml, messages:)
          xml.REQUESTDATA do
            messages.each do |fragment|
              # Each fragment is already a complete <TALLYMESSAGE> XML string.
              # We parse and graft it in to avoid double-encoding.
              inject_fragment(xml, fragment)
            end
          end
        end

        # Parses a raw XML fragment string and appends its root node as a child
        # of the current builder context.
        #
        # If the fragment is already a Nokogiri node, it is simply <<-appended.
        def inject_fragment(xml, fragment)
          node = case fragment
                 when String
                   Nokogiri::XML.fragment(fragment).children.first
                 when Nokogiri::XML::Node, Nokogiri::XML::DocumentFragment
                   fragment.children.first
                 end

          xml.parent << node if node
        rescue Nokogiri::XML::SyntaxError => e
          raise Error, "EnvelopeBuilder: malformed inner XML fragment — #{e.message}"
        end
      end
    end
  end
end
