# frozen_string_literal: true

module Gst
  module Gstr3b
    # Builds the GSTR-3B return from the organization's books for a calendar month.
    #
    # GSTR-3B sections computed:
    #   Table 3.1 — Outward + inward (reverse charge) supplies liable to tax
    #   Table 4   — Eligible ITC
    #   Table 5   — Exempt / Nil-rated / Non-GST outward supplies
    #
    # Usage:
    #   result = Gst::Gstr3b::Builder.call(
    #     organization: org,
    #     branch:       branch,   # optional
    #     month:        9,
    #     year:         2025
    #   )
    #   result.success?
    #   result.period      # GstReturnPeriod
    #   result.snapshot    # GstReturnSnapshot (section_key: 'gstr3b_full')
    #   result.payload     # Hash — the 3B tables
    #
    class Builder
      BuildResult = Struct.new(:success, :period, :snapshot, :payload, :errors, keyword_init: true) do
        def success?; success; end
        def failure?; !success; end
      end

      FINALIZED_STATUSES = %w[issued partially_paid paid].freeze

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
        period_from = Date.new(@year, @month, 1)
        period_to   = period_from.end_of_month

        period = resolve_period!

        if period.filed?
          return BuildResult.new(
            success:  false,
            period:   period,
            snapshot: period.filed_snapshot,
            payload:  nil,
            errors:   ['GSTR-3B period already filed']
          )
        end

        payload = compute_3b(period_from, period_to)
        snapshot = save_snapshot!(period, payload)
        period.mark_generated!(source_hash: compute_source_hash(period_from, period_to))

        BuildResult.new(success: true, period: period, snapshot: snapshot, payload: payload, errors: [])

      rescue StandardError => e
        Rails.logger.error("[Gst::Gstr3b::Builder] #{e.class}: #{e.message}")
        BuildResult.new(success: false, period: nil, snapshot: nil, payload: nil, errors: [e.message])
      end

      private

      def resolve_period!
        resolver = Gst::Support::ReturnPeriodResolver.new(
          organization: @organization, branch: @branch
        )
        resolver.find_or_create!(month: @month, year: @year, return_type: 'gstr3b').period
      end

      # ── Table 3.1: Outward supplies ────────────────────────────────────────

      def compute_3b(period_from, period_to)
        invoices     = fetch_sales_invoices(period_from, period_to)
        credit_notes = fetch_credit_notes(period_from, period_to)

        # Separate inter-state / intra-state / exempt / nil-rated / reverse charge
        # Classification is derived from line gst_rate (no tax_type column on SalesInvoice)
        taxable_inter   = invoices.select { |i| inter_state?(i) && taxable_invoice?(i) }
        taxable_intra   = invoices.select { |i| !inter_state?(i) && taxable_invoice?(i) }
        zero_rated      = [] # exports not yet explicitly tracked in the current schema
        nil_exempt      = invoices.select { |i| !taxable_invoice?(i) }
        non_gst         = [] # non-GST flag not yet tracked in the current schema

        purchases       = fetch_purchase_invoices(period_from, period_to)
        rc_purchases    = purchases.select { |p| p.is_reverse_charge? }

        itc_eligible    = purchases.select { |p| !p.is_reverse_charge? && p.itc_eligible? rescue true }

        # Credit note adjustments
        cn_taxable_val  = credit_notes.sum { |cn| cn.subtotal.to_d }
        cn_tax_val      = credit_notes.sum { |cn| cn.tax_total.to_d }

        {
          period_from: period_from.iso8601,
          period_to:   period_to.iso8601,
          month:       @month,
          year:        @year,
          table_3_1: {
            outward_taxable_supplies: {
              taxable_value: sum_taxable(invoices) - cn_taxable_val,
              igst:          sum_field(invoices, :igst_amount) - sum_field(credit_notes, :igst_amount),
              cgst:          sum_field(invoices, :cgst_amount) - sum_field(credit_notes, :cgst_amount),
              sgst:          sum_field(invoices, :sgst_amount) - sum_field(credit_notes, :sgst_amount),
              cess:          sum_field(invoices, :cess_amount) - sum_field(credit_notes, :cess_amount)
            },
            outward_zero_rated: {
              taxable_value: sum_taxable(zero_rated),
              igst:          sum_field(zero_rated, :igst_amount)
            },
            outward_nil_exempt: {
              taxable_value: sum_taxable(nil_exempt)
            },
            inward_rc_taxable: {
              taxable_value: sum_taxable(rc_purchases),
              igst:          sum_field(rc_purchases, :igst_amount),
              cgst:          sum_field(rc_purchases, :cgst_amount),
              sgst:          sum_field(rc_purchases, :sgst_amount),
              cess:          sum_field(rc_purchases, :cess_amount)
            },
            non_gst_supplies: {
              taxable_value: sum_taxable(non_gst)
            }
          },
          table_4: {
            itc_available: {
              igst: sum_field(itc_eligible, :igst_amount),
              cgst: sum_field(itc_eligible, :cgst_amount),
              sgst: sum_field(itc_eligible, :sgst_amount),
              cess: sum_field(itc_eligible, :cess_amount)
            },
            itc_reverse_charge: {
              igst: sum_field(rc_purchases, :igst_amount),
              cgst: sum_field(rc_purchases, :cgst_amount),
              sgst: sum_field(rc_purchases, :sgst_amount),
              cess: sum_field(rc_purchases, :cess_amount)
            }
          },
          table_5: {
            nil_exempt_non_gst: {
              inter_state:  sum_taxable(nil_exempt.select { |i| inter_state?(i) }),
              intra_state:  sum_taxable(nil_exempt.reject { |i| inter_state?(i) }),
              non_gst:      sum_taxable(non_gst)
            }
          },
          metadata: {
            invoice_count:      invoices.size,
            credit_note_count:  credit_notes.size,
            purchase_count:     purchases.size,
            rc_purchase_count:  rc_purchases.size,
            generated_at:       Time.current.iso8601
          }
        }
      end

      # ── Data fetchers ─────────────────────────────────────────────────────────

      def fetch_sales_invoices(from, to)
        scope = SalesInvoice.where(
          organization_id: @organization.id,
          status:          FINALIZED_STATUSES,
          invoice_date:    from..to
        )
        scope = scope.where(branch_id: @branch.id) if @branch
        scope.includes(:lines).to_a
      end

      def fetch_credit_notes(from, to)
        scope = CreditNote.where(
          organization_id: @organization.id,
          issued_at:       from..to
        )
        scope = scope.where(branch_id: @branch.id) if @branch
        scope.includes(:lines).to_a
      end

      def fetch_purchase_invoices(from, to)
        scope = PurchaseInvoice.where(
          organization_id: @organization.id,
          invoice_date:    from..to,
          status:          %w[received approved paid]
        )
        scope = scope.where(branch_id: @branch.id) if @branch
        scope.to_a
      end

      # ── Helpers ─────────────────────────────────────────────────────────────

      # Returns true if the invoice carries any positive-rate GST lines.
      # Invoices where all lines have gst_rate == 0 are treated as nil-rated / exempt.
      def taxable_invoice?(invoice)
        invoice.lines.any? { |l| l.gst_rate.to_d > 0 }
      end

      def inter_state?(doc)
        # Uses SectionClassifier logic for consistency
        seller_code = doc.try(:branch)&.state_code.presence || '00'
        Gst::Gstr1::SectionClassifier.inter_state?(doc, seller_state_code: seller_code)
      rescue StandardError
        false
      end

      def sum_taxable(docs)
        docs.sum { |d| d.subtotal.to_d }.round(2)
      end

      def sum_field(docs, field)
        docs.sum { |d| d.public_send(field).to_d rescue 0 }.round(2)
      end

      def compute_source_hash(from, to)
        ids = SalesInvoice.where(
          organization_id: @organization.id,
          status:          FINALIZED_STATUSES,
          invoice_date:    from..to
        ).pluck(:id, :updated_at).map { |id, ua| "#{id}:#{ua.to_i}" }.sort
        Digest::SHA256.hexdigest(ids.to_json)
      end

      def save_snapshot!(period, payload)
        next_version = (period.current_version || 0) + 1
        totals = {
          taxable_value: payload.dig(:table_3_1, :outward_taxable_supplies, :taxable_value),
          igst:          payload.dig(:table_3_1, :outward_taxable_supplies, :igst),
          cgst:          payload.dig(:table_3_1, :outward_taxable_supplies, :cgst),
          sgst:          payload.dig(:table_3_1, :outward_taxable_supplies, :sgst)
        }
        GstReturnSnapshot.create!(
          gst_return_period:  period,
          organization:       @organization,
          section_key:        'gstr3b_full',
          payload:            payload,
          totals:             totals,
          source_counts:      payload.dig(:metadata) || {},
          source_invoice_ids: {},
          generated_at:       Time.current,
          version_number:     next_version,
          snapshot_hash:      Digest::SHA256.hexdigest(payload.to_json),
          is_filed:           false
        )
      end
    end
  end
end
