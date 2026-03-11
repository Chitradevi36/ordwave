# frozen_string_literal: true

module Gst
  module Gstr3b
    # Compares the GSTR-3B computation against the filed/latest GSTR-1 and GSTR-2B
    # for the same period, surfacing differences a CA should resolve before filing.
    #
    # Compares:
    #   Axis A — Outward supplies: GSTR-1 taxable+tax vs GSTR-3B Table 3.1
    #   Axis B — ITC credit:       GSTR-2B import totals vs GSTR-3B Table 4
    #
    # Usage:
    #   result = Gst::Gstr3b::VarianceReporter.call(
    #     organization: org, month: 2, year: 2026
    #   )
    #   result.status            # :complete / :partial / :missing_data
    #   result.gstr1_vs_3b       # Hash — outward supply comparison
    #   result.gstr2b_vs_3b      # Hash — ITC comparison
    #   result.has_variances?    # true if any cell exceeds tolerance
    #
    class VarianceReporter
      TOLERANCE = BigDecimal('1.0')  # ₹1 rounding tolerance

      VarianceResult = Struct.new(
        :status,            # :complete / :partial / :missing_data
        :month,
        :year,
        :gstr1_vs_3b,       # Hash
        :gstr2b_vs_3b,      # Hash
        :summary,           # Hash — high-level flags
        :errors,
        keyword_init: true
      ) do
        def has_variances?
          return false unless status == :complete || status == :partial
          [gstr1_vs_3b, gstr2b_vs_3b].compact.any? do |section|
            section[:cells]&.any? { |c| c[:variance_flag] }
          end
        end

        def complete?; status == :complete; end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(organization:, month:, year:, branch: nil)
        @organization = organization
        @month        = month
        @year         = year
        @branch       = branch
        @errors       = []
      end

      def call
        gstr1_snap  = find_snapshot('gstr1',         'gstr1_full')
        gstr3b_snap = find_snapshot('gstr3b',        'gstr3b_full')
        gstr2b_imp  = find_gst2b_import

        status =
          if gstr1_snap && gstr3b_snap
            gstr2b_imp ? :complete : :partial
          elsif gstr3b_snap
            @errors << "No GSTR-1 snapshot found for #{@month}/#{@year}. Generate GSTR-1 first."
            :missing_data
          else
            @errors << "No GSTR-3B snapshot found for #{@month}/#{@year}. Generate GSTR-3B first."
            :missing_data
          end

        VarianceResult.new(
          status:       status,
          month:        @month,
          year:         @year,
          gstr1_vs_3b:  status != :missing_data && gstr1_snap ? compare_gstr1_vs_3b(gstr1_snap, gstr3b_snap) : nil,
          gstr2b_vs_3b: gstr2b_imp && gstr3b_snap ? compare_gstr2b_vs_3b(gstr2b_imp, gstr3b_snap) : nil,
          summary:      build_summary(gstr1_snap, gstr3b_snap, gstr2b_imp),
          errors:       @errors
        )
      rescue StandardError => e
        Rails.logger.error("[Gst::Gstr3b::VarianceReporter] #{e.class}: #{e.message}")
        VarianceResult.new(
          status: :missing_data, month: @month, year: @year,
          gstr1_vs_3b: nil, gstr2b_vs_3b: nil, summary: {}, errors: [e.message]
        )
      end

      private

      # ── Axis A: GSTR-1 outward vs GSTR-3B Table 3.1 ─────────────────────────

      def compare_gstr1_vs_3b(gstr1_snap, gstr3b_snap)
        # GSTR-1 totals come from its snapshot totals hash
        g1 = gstr1_snap.totals || {}
        # GSTR-3B Table 3.1 outward taxable supplies
        g3 = gstr3b_snap.payload&.dig('table_3_1', 'outward_taxable_supplies') ||
             gstr3b_snap.payload&.dig(:table_3_1, :outward_taxable_supplies) || {}

        gstr1_taxable = (g1['total_taxable'] || g1[:total_taxable]).to_d
        gstr3b_taxable = (g3['taxable_value'] || g3[:taxable_value]).to_d

        gstr1_igst = (g1['total_igst'] || g1[:total_igst]).to_d
        gstr3b_igst = (g3['igst'] || g3[:igst]).to_d

        gstr1_cgst = (g1['total_cgst'] || g1[:total_cgst]).to_d
        gstr3b_cgst = (g3['cgst'] || g3[:cgst]).to_d

        gstr1_sgst = (g1['total_sgst'] || g1[:total_sgst]).to_d
        gstr3b_sgst = (g3['sgst'] || g3[:sgst]).to_d

        gstr1_snap_meta = {
          id:          gstr1_snap.id,
          section_key: gstr1_snap.section_key,
          is_filed:    gstr1_snap.is_filed,
          version:     gstr1_snap.version_number,
          generated_at: gstr1_snap.generated_at
        }
        gstr3b_snap_meta = {
          id:           gstr3b_snap.id,
          section_key:  gstr3b_snap.section_key,
          is_filed:     gstr3b_snap.is_filed,
          version:      gstr3b_snap.version_number,
          generated_at: gstr3b_snap.generated_at
        }

        cells = [
          build_cell('taxable_value', 'Taxable Value',    gstr1_taxable, gstr3b_taxable),
          build_cell('igst',          'IGST',             gstr1_igst,    gstr3b_igst),
          build_cell('cgst',          'CGST',             gstr1_cgst,    gstr3b_cgst),
          build_cell('sgst',          'SGST / UTGST',     gstr1_sgst,    gstr3b_sgst),
        ]

        {
          axis:           'gstr1_vs_3b',
          label:          'Outward Supplies: GSTR-1 vs GSTR-3B (Table 3.1)',
          gstr1_snapshot: gstr1_snap_meta,
          gstr3b_snapshot: gstr3b_snap_meta,
          cells:          cells,
          has_variance:   cells.any? { |c| c[:variance_flag] }
        }
      end

      # ── Axis B: GSTR-2B ITC vs GSTR-3B Table 4 ──────────────────────────────

      def compare_gstr2b_vs_3b(gstr2b_imp, gstr3b_snap)
        g2b_igst = gstr2b_imp.gst2b_import_lines
                              .where(itc_available: true)
                              .where.not(match_status: %w[missing_in_books ignored])
                              .sum(:igst).to_d
        g2b_cgst = gstr2b_imp.gst2b_import_lines
                              .where(itc_available: true)
                              .where.not(match_status: %w[missing_in_books ignored])
                              .sum(:cgst).to_d
        g2b_sgst = gstr2b_imp.gst2b_import_lines
                              .where(itc_available: true)
                              .where.not(match_status: %w[missing_in_books ignored])
                              .sum(:sgst).to_d

        g3 = gstr3b_snap.payload&.dig('table_4', 'itc_available') ||
             gstr3b_snap.payload&.dig(:table_4, :itc_available) || {}

        g3b_igst = (g3['igst'] || g3[:igst]).to_d
        g3b_cgst = (g3['cgst'] || g3[:cgst]).to_d
        g3b_sgst = (g3['sgst'] || g3[:sgst]).to_d

        cells = [
          build_cell('igst', 'IGST ITC', g2b_igst, g3b_igst),
          build_cell('cgst', 'CGST ITC', g2b_cgst, g3b_cgst),
          build_cell('sgst', 'SGST ITC', g2b_sgst, g3b_sgst),
        ]

        gstr2b_unmatched_count = gstr2b_imp.gst2b_import_lines
                                            .where(match_status: 'missing_in_books').count
        gstr2b_mismatch_count  = gstr2b_imp.gst2b_import_lines
                                            .where(match_status: 'tax_mismatch').count

        {
          axis:                    'gstr2b_vs_3b',
          label:                   'ITC: GSTR-2B (matched lines) vs GSTR-3B (Table 4)',
          gstr2b_import_id:        gstr2b_imp.id,
          gstr2b_import_status:    gstr2b_imp.import_status,
          gstr2b_unmatched_lines:  gstr2b_unmatched_count,
          gstr2b_tax_mismatch_lines: gstr2b_mismatch_count,
          cells:                   cells,
          has_variance:            cells.any? { |c| c[:variance_flag] },
          note:                    gstr2b_unmatched_count > 0 ?
            "#{gstr2b_unmatched_count} lines missing in books — ITC at risk. Book or dispute before filing." :
            nil
        }
      end

      # ── Summary ───────────────────────────────────────────────────────────────

      def build_summary(gstr1_snap, gstr3b_snap, gstr2b_imp)
        {
          period:                 "#{Date::MONTHNAMES[@month]} #{@year}",
          gstr1_available:        gstr1_snap.present?,
          gstr1_filed:            gstr1_snap&.is_filed || false,
          gstr3b_available:       gstr3b_snap.present?,
          gstr3b_filed:           gstr3b_snap&.is_filed || false,
          gstr2b_available:       gstr2b_imp.present?,
          gstr2b_import_status:   gstr2b_imp&.import_status,
          ready_to_file:          gstr1_snap&.is_filed && gstr3b_snap.present? && gstr2b_imp.present?
        }
      end

      # ── Helpers ───────────────────────────────────────────────────────────────

      def build_cell(key, label, source_value, target_value)
        diff = (source_value - target_value).round(2)
        {
          key:           key,
          label:         label,
          source_value:  source_value.round(2),
          target_value:  target_value.round(2),
          difference:    diff,
          variance_flag: diff.abs > TOLERANCE
        }
      end

      def find_snapshot(return_type, section_key)
        period = GstReturnPeriod.find_by(
          organization_id: @organization.id,
          month:           @month,
          year:            @year,
          return_type:     return_type,
          branch_id:       @branch&.id
        )
        return nil unless period

        # Prefer filed snapshot; fall back to latest
        period.gst_return_snapshots.find_by(section_key: section_key, is_filed: true) ||
          period.gst_return_snapshots.where(section_key: section_key)
                                     .order(version_number: :desc).first
      end

      def find_gst2b_import
        Gst2bImport.find_by(
          organization_id: @organization.id,
          month:           @month,
          year:            @year,
          branch_id:       @branch&.id
        )
      end
    end
  end
end
