# frozen_string_literal: true

module Gst
  module Gstr2b
    # Orchestrates the full GSTR-2B import pipeline:
    #   1. Validate input (GSTIN, month, year)
    #   2. Detect duplicate imports
    #   3. Parse JSON using Parser
    #   4. Persist Gst2bImportLine records
    #   5. Run MatchingEngine
    #   6. Return structured result
    #
    # Usage:
    #   result = Gst::Gstr2b::Importer.call(
    #     organization:  org,
    #     branch:        branch,
    #     gstin:         '27AAPFU0939F1ZV',
    #     month:         9,
    #     year:          2025,
    #     raw_payload:   json_hash,
    #     file_name:     'GSTR2B_092025.json',
    #     imported_by:   current_user
    #   )
    #   result.success?
    #   result.import      # Gst2bImport record
    #   result.errors      # []
    #
    class Importer
      ImportResult = Struct.new(:success, :import, :errors, keyword_init: true) do
        def success?; success; end
        def failure?; !success; end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(organization:, gstin:, month:, year:, raw_payload:,
                     branch: nil, file_name: nil, imported_by: nil)
        @organization = organization
        @branch       = branch
        @gstin        = gstin.present? ? gstin.upcase.strip : gstin
        @month        = month
        @year         = year
        @raw_payload  = raw_payload
        @file_name    = file_name
        @imported_by  = imported_by
      end

      def call
        errors = []

        # ── Validation ─────────────────────────────────────────────────────────
        unless valid_gstin?
          return ImportResult.new(success: false, import: nil,
                                  errors: ['GSTIN is invalid or missing'])
        end
        unless valid_period?
          return ImportResult.new(success: false, import: nil,
                                  errors: ['Month must be 1-12 and year must be provided'])
        end

        # ── Resolve FinancialYear ──────────────────────────────────────────────
        fy = Gst::Support::FinancialYearResolver.new(organization: @organization)
               .find_or_create_for_period!(month: @month, year: @year)

        # ── Create import record ───────────────────────────────────────────────
        import = Gst2bImport.create!(
          organization:         @organization,
          branch:               @branch,
          financial_year:       fy,
          financial_year_label: fy.code,
          gstin:                @gstin,
          month:                @month,
          year:                 @year,
          period_start_on:      Date.new(@year, @month, 1),
          period_end_on:        Date.new(@year, @month, 1).end_of_month,
          file_name:            @file_name,
          source_type:          'json',
          import_status:        'uploaded',
          raw_payload:          @raw_payload,
          imported_by:          @imported_by,
          imported_at:          Time.current
        )

        # ── Duplicate detection ───────────────────────────────────────────────
        source_hash = import.compute_source_hash
        import.update!(source_hash: source_hash)

        if import.duplicate_import?
          import.mark_failed!('Duplicate: identical payload already imported for this GSTIN/period')
          return ImportResult.new(success: false, import: import,
                                  errors: ['A duplicate import exists for this period and GSTIN'])
        end

        # ── Parse ──────────────────────────────────────────────────────────────
        import.mark_parsing!
        parse_result = Gst::Gstr2b::Parser.call(json_payload: @raw_payload)

        if parse_result.failure? && parse_result.lines.empty?
          import.mark_failed!(parse_result.errors.first)
          return ImportResult.new(success: false, import: import, errors: parse_result.errors)
        end

        # ── Persist lines ──────────────────────────────────────────────────────
        import.mark_parsed!(row_count: parse_result.lines.count)

        bulk_create_lines!(import, parse_result.lines)

        # ── Match ──────────────────────────────────────────────────────────────
        MatchingEngine.new(gst2b_import: import, organization: @organization).run!

        ImportResult.new(success: true, import: import.reload, errors: [])

      rescue ActiveRecord::RecordInvalid => e
        ImportResult.new(success: false, import: nil, errors: [e.message])
      rescue StandardError => e
        Rails.logger.error("[Gst::Gstr2b::Importer] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        import&.mark_failed!(e.message)
        ImportResult.new(success: false, import: import, errors: [e.message])
      end

      private

      def valid_gstin?
        @gstin.present? &&
          @gstin.match?(/\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/)
      end

      def valid_period?
        @month.to_i.between?(1, 12) && @year.to_i > 2000
      end

      def bulk_create_lines!(import, lines_data)
        now = Time.current
        # Prepare AttributeObjects and insert in batches
        lines_data.each_slice(200) do |batch|
          attrs = batch.map do |line|
            line.merge(
              gst2b_import_id:  import.id,
              organization_id:  @organization.id,
              created_at:       now,
              updated_at:       now
            )
          end
          Gst2bImportLine.insert_all(attrs) if attrs.any?
        end
      end
    end
  end
end
