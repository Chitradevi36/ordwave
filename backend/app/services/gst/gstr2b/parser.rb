# frozen_string_literal: true

module Gst
  module Gstr2b
    # Parses a raw GSTR-2B JSON payload (as downloaded from the GST portal)
    # into an array of normalized line hashes ready to be persisted as
    # Gst2bImportLine records.
    #
    # GSTR-2B JSON structure (portal format):
    #   { data: { docdata: { b2b: [...], b2ba: [...], cdn: [...], cdna: [...],
    #                        impg: [...], impgsez: [...], isd: [...] } } }
    #
    # Usage:
    #   result = Gst::Gstr2b::Parser.call(json_payload: hash)
    #   result.success?
    #   result.lines     # Array of normalized attribute hashes
    #   result.errors    # Array of error strings
    #
    class Parser
      ParseResult = Struct.new(:success, :lines, :errors, keyword_init: true) do
        def success?; success; end
        def failure?; !success; end
      end

      SECTION_MAP = {
        'b2b'    => { section_type: 'b2b',    document_type: 'invoice',     itc: true  },
        'b2ba'   => { section_type: 'b2ba',   document_type: 'invoice',     itc: true  },
        'cdn'    => { section_type: 'cdn',    document_type: 'credit_note', itc: true  },
        'cdna'   => { section_type: 'cdna',   document_type: 'credit_note', itc: true  },
        'isd'    => { section_type: 'isd',    document_type: 'isd',         itc: true  },
        'impg'   => { section_type: 'impg',   document_type: 'invoice',     itc: true  },
        'impgsez'=> { section_type: 'impgsez',document_type: 'invoice',     itc: true  }
      }.freeze

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(json_payload:)
        @payload = json_payload
      end

      def call
        lines  = []
        errors = []

        begin
          docdata = dig_docdata!
          SECTION_MAP.each do |section_key, meta|
            entries = Array(docdata[section_key])
            entries.each_with_index do |entry, idx|
              parsed = parse_section_entry(entry, section_key, meta)
              lines.concat(parsed)
            rescue StandardError => e
              errors << "#{section_key}[#{idx}]: #{e.message}"
            end
          end
        rescue StandardError => e
          return ParseResult.new(success: false, lines: [], errors: [e.message])
        end

        ParseResult.new(
          success: errors.empty?,
          lines:   lines,
          errors:  errors
        )
      end

      private

      # GSTR-2B portal JSON nesting can vary; handle both v1 (data.docdata) and
      # direct docdata keys for older/test formats.
      def dig_docdata!
        payload = @payload.is_a?(String) ? JSON.parse(@payload) : @payload.deep_stringify_keys

        docdata = payload.dig('data', 'docdata') ||
                  payload.dig('docdata')         ||
                  payload

        raise ArgumentError, "Cannot locate docdata in GSTR-2B payload" if docdata.blank?
        docdata
      end

      # Supplier-level entry: { ctin: GSTIN, trdnm: name, inv: [...] }
      def parse_section_entry(entry, section_key, meta)
        supplier_gstin = entry['ctin']&.strip&.upcase
        supplier_name  = entry['trdnm']&.strip

        invoices = Array(entry['inv'])
        invoices.flat_map do |inv|
          parse_invoice(inv, supplier_gstin, supplier_name, section_key, meta)
        end
      end

      def parse_invoice(inv, supplier_gstin, supplier_name, section_key, meta)
        invoice_number = inv['inum']&.strip&.upcase
        invoice_date   = parse_date(inv['dt'])
        invoice_value  = inv['val']&.to_d

        # Each invoice can have multiple items (pos = place of supply entries)
        items = Array(inv['itms'])
        if items.empty?
          # Flat format (impg / some isd)
          return [build_line(
            supplier_gstin:  supplier_gstin,
            supplier_name:   supplier_name,
            invoice_number:  invoice_number,
            invoice_date:    invoice_date,
            invoice_value:   invoice_value,
            taxable_value:   inv['txval']&.to_d,
            igst:            (inv['iamt'] || inv['igst'])&.to_d,
            cgst:            inv['camt']&.to_d,
            sgst:            inv['samt']&.to_d,
            cess:            inv['csamt']&.to_d,
            place_of_supply: inv['pos'],
            reverse_charge:  inv['rev'] == 'Y',
            itc_available:   meta[:itc],
            itc_reversal:    inv['eligibility'],
            document_type:   meta[:document_type],
            section_type:    meta[:section_type]
          )]
        end

        items.map do |item|
          detail = item['itm_det'] || item
          build_line(
            supplier_gstin:  supplier_gstin,
            supplier_name:   supplier_name,
            invoice_number:  invoice_number,
            invoice_date:    invoice_date,
            invoice_value:   invoice_value,
            taxable_value:   detail['txval']&.to_d,
            igst:            (detail['iamt'] || detail['igst'])&.to_d,
            cgst:            detail['camt']&.to_d,
            sgst:            detail['samt']&.to_d,
            cess:            detail['csamt']&.to_d,
            place_of_supply: inv['pos'] || item['pos'],
            reverse_charge:  inv['rev'] == 'Y',
            itc_available:   meta[:itc],
            itc_reversal:    detail['eligibility'] || inv['eligibility'],
            document_type:   meta[:document_type],
            section_type:    meta[:section_type]
          )
        end
      end

      def build_line(**attrs)
        {
          supplier_gstin:   attrs[:supplier_gstin],
          supplier_name:    attrs[:supplier_name],
          invoice_number:   attrs[:invoice_number],
          invoice_date:     attrs[:invoice_date],
          invoice_value:    attrs[:invoice_value],
          taxable_value:    attrs[:taxable_value],
          igst:             attrs[:igst],
          cgst:             attrs[:cgst],
          sgst:             attrs[:sgst],
          cess:             attrs[:cess],
          place_of_supply:  attrs[:place_of_supply],
          reverse_charge:   attrs[:reverse_charge] || false,
          itc_available:    attrs[:itc_available] != false,
          itc_reversal_reason: attrs[:itc_reversal],
          document_type:    attrs[:document_type],
          section_type:     attrs[:section_type],
          match_status:     'pending',
          match_confidence: nil
        }.compact
      end

      def parse_date(str)
        return nil if str.blank?
        # Portal format: DD-MM-YYYY or DD/MM/YYYY
        parts = str.split(%r{[-/]})
        return nil if parts.length != 3
        Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
      rescue ArgumentError
        nil
      end
    end
  end
end
