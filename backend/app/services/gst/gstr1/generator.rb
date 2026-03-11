# frozen_string_literal: true

module Gst
  module Gstr1
    # Period-aware orchestrator for GSTR-1 generation.
    #
    # Wraps Gstr1ExportService with:
    #   - GstReturnPeriod tracking (creates or finds the period record)
    #   - Snapshot storage (versioned, immutable after filing)
    #   - Source hash for change detection
    #   - Error / warning counts surfaced onto the period
    #
    # Usage:
    #   result = Gst::Gstr1::Generator.call(
    #     organization: org,
    #     branch:       branch,    # optional
    #     month:        9,
    #     year:         2025
    #   )
    #   result.success?
    #   result.period          # GstReturnPeriod
    #   result.snapshot        # GstReturnSnapshot (full section)
    #   result.export_result   # Gstr1ExportService::Result
    #   result.summary         # human-readable hash for API
    #   result.portal_json     # GST portal JSON
    #   result.errors          # [] on success
    #
    class Generator
      GeneratorResult = Struct.new(
        :success,
        :period,
        :snapshot,
        :export_result,
        :errors,
        keyword_init: true
      ) do
        def success?; success; end
        def failure?; !success; end

        def summary
          export_result&.summary
        end

        def portal_json
          export_result&.portal_json
        end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(organization:, month:, year:, branch: nil)
        @organization = organization
        @month        = month
        @year         = year
        @branch       = branch
      end

      def call
        period      = resolve_period!
        period_from = Date.new(@year, @month, 1)
        period_to   = period_from.end_of_month

        # Guard: period already filed → do not regenerate
        if period.filed?
          return GeneratorResult.new(
            success:       false,
            period:        period,
            snapshot:      period.filed_snapshot,
            export_result: nil,
            errors:        ['This return period has already been filed and cannot be regenerated']
          )
        end

        # Run core GSTR-1 pipeline
        export_result = Gst::Gstr1ExportService.call(
          organization: @organization,
          period_from:  period_from,
          period_to:    period_to,
          branch_id:    @branch&.id
        )

        validation   = export_result.validation_result
        error_count  = validation.errors.count
        warning_count = validation.warnings.count

        # Compute source fingerprint for change detection
        source_hash = compute_source_hash(export_result)

        # Save snapshot
        snapshot = save_snapshot!(
          period:        period,
          export_result: export_result,
          source_hash:   source_hash
        )

        # Advance period status
        period.mark_generated!(
          source_hash:   source_hash,
          error_count:   error_count,
          warning_count: warning_count
        )

        GeneratorResult.new(
          success:       true,
          period:        period,
          snapshot:      snapshot,
          export_result: export_result,
          errors:        []
        )

      rescue StandardError => e
        Rails.logger.error("[Gst::Gstr1::Generator] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        GeneratorResult.new(
          success:       false,
          period:        nil,
          snapshot:      nil,
          export_result: nil,
          errors:        [e.message]
        )
      end

      private

      def resolve_period!
        resolver = Gst::Support::ReturnPeriodResolver.new(
          organization: @organization,
          branch:       @branch
        )
        result = resolver.find_or_create!(month: @month, year: @year, return_type: 'gstr1')
        result.period
      end

      def compute_source_hash(export_result)
        ids = (
          export_result.b2b_invoices + export_result.b2cl_invoices +
          export_result.b2cs_invoices + export_result.cdnr_notes +
          export_result.cdnur_notes
        ).map { |d| "#{d.class.name}:#{d.id}:#{d.updated_at.to_i}" }.sort

        Digest::SHA256.hexdigest(ids.to_json)
      end

      def save_snapshot!(period:, export_result:, source_hash:)
        # Determine next version number
        next_version = (period.current_version || 0) + 1

        payload = export_result.summary
        totals  = extract_totals(export_result)
        counts  = export_result.counts

        source_invoice_ids = {
          b2b:   export_result.b2b_invoices.map(&:id),
          b2cl:  export_result.b2cl_invoices.map(&:id),
          b2cs:  export_result.b2cs_invoices.map(&:id),
          cdnr:  export_result.cdnr_notes.map(&:id),
          cdnur: export_result.cdnur_notes.map(&:id)
        }

        snapshot_hash = Digest::SHA256.hexdigest(payload.to_json)

        GstReturnSnapshot.create!(
          gst_return_period:   period,
          organization:        @organization,
          section_key:         'full',
          payload:             payload,
          totals:              totals,
          source_counts:       counts,
          source_invoice_ids:  source_invoice_ids,
          generated_at:        Time.current,
          version_number:      next_version,
          source_hash:         source_hash,
          snapshot_hash:       snapshot_hash,
          is_filed:            false
        )
      end

      def extract_totals(export_result)
        t = export_result.totals
        {
          taxable_value: t[:taxable].to_f.round(2),
          tax_value:     t[:tax].to_f.round(2),
          total_value:   t[:total].to_f.round(2)
        }
      end
    end
  end
end
