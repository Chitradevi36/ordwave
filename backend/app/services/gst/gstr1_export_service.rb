# frozen_string_literal: true

module Gst
  # Orchestrates the full GSTR-1 data pipeline for a given period.
  #
  # Responsibilities:
  #   1. Fetch all finalized invoices and credit notes for the period.
  #   2. Classify each document into its GSTR-1 section (B2B, B2CL, B2CS, CDNR, CDNUR).
  #   3. Run the validator and surface errors / warnings.
  #   4. Expose classified data so that callers can choose:
  #      - SummaryBuilder → human-readable preview (used by the API preview endpoint)
  #      - JsonBuilder    → GST portal upload JSON (used by the export endpoint)
  #
  # Bug fixes vs original implementation:
  #   - Invoice status filter now includes 'paid' and 'partially_paid' (not just 'issued').
  #   - SectionClassifier drives all inter-state / section logic (was duplicated inline).
  #   - Credit note taxable value uses line_total − tax_amount (not unit_price × qty).
  #   - Credit note CGST/SGST split uses actual inter/intra determination (not always /2).
  #   - B2CS sply_ty is 'INTRA' for intra-state (was 'OE', which is not a portal value).
  #   - STATE_CODES map is now canonical in SectionClassifier (single source of truth).
  #
  # Usage:
  #   result = Gst::Gstr1ExportService.call(
  #     organization: org,
  #     period_from:  Date.new(2026, 3, 1),
  #     period_to:    Date.new(2026, 3, 31)
  #   )
  #   result.b2b_invoices        # [SalesInvoice, ...]   classified set
  #   result.validation_result.valid?
  #   result.summary             # Hash matching frontend shape (SummaryBuilder output)
  #   result.portal_json         # Hash for GST portal upload (JsonBuilder output)
  #
  class Gstr1ExportService
    # Finalized invoice statuses to include in GSTR-1.
    FINALIZED_STATUSES = %w[issued partially_paid paid].freeze

    Result = Struct.new(
      :gstin,
      :return_period,       # MMYYYY string
      :period_from,
      :period_to,
      :seller_state_code,
      :b2b_invoices,
      :b2cl_invoices,
      :b2cs_invoices,
      :cdnr_notes,
      :cdnur_notes,
      :validation_result,
      keyword_init: true
    ) do
      # Delegate to SummaryBuilder — human-readable preview for API response.
      def summary
        @summary ||= Gst::Gstr1::SummaryBuilder.call(
          period_from:       period_from,
          period_to:         period_to,
          b2b_invoices:      b2b_invoices,
          b2cl_invoices:     b2cl_invoices,
          b2cs_invoices:     b2cs_invoices,
          cdnr_notes:        cdnr_notes,
          cdnur_notes:       cdnur_notes,
          seller_state_code: seller_state_code
        ).merge(gstin: gstin)
      end

      # Delegate to JsonBuilder — GST portal upload JSON.
      def portal_json
        @portal_json ||= Gst::Gstr1::JsonBuilder.call(
          gstin:             gstin,
          return_period:     return_period,
          b2b_invoices:      b2b_invoices,
          b2cl_invoices:     b2cl_invoices,
          b2cs_invoices:     b2cs_invoices,
          cdnr_notes:        cdnr_notes,
          cdnur_notes:       cdnur_notes,
          seller_state_code: seller_state_code
        )
      end

      # Convenience counts for audit record creation.
      def counts
        {
          b2b:          b2b_invoices.size,
          b2cl:         b2cl_invoices.size,
          b2cs:         b2cs_invoices.size,
          cdnr:         cdnr_notes.size,
          cdnur:        cdnur_notes.size,
          invoices:     b2b_invoices.size + b2cl_invoices.size + b2cs_invoices.size,
          credit_notes: cdnr_notes.size + cdnur_notes.size
        }
      end

      # Convenience totals for audit record creation.
      def totals
        all_invoices     = b2b_invoices + b2cl_invoices + b2cs_invoices
        all_credit_notes = cdnr_notes + cdnur_notes

        {
          taxable: all_invoices.sum { |i| i.subtotal.to_d } -
                   all_credit_notes.sum { |cn| cn.subtotal.to_d },
          tax:     all_invoices.sum { |i| i.tax_total.to_d } -
                   all_credit_notes.sum { |cn| cn.tax_total.to_d },
          total:   all_invoices.sum { |i| i.grand_total.to_d } -
                   all_credit_notes.sum { |cn| cn.total.to_d }
        }
      end
    end

    # ── STATE_CODES stays here as a public constant so Validator can reference it.
    # The canonical map lives in SectionClassifier; this is an alias.
    STATE_CODES = Gst::Gstr1::SectionClassifier::STATE_CODE_MAP

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, period_from:, period_to:, branch_id: nil)
      @organization = organization
      @period_from  = period_from
      @period_to    = period_to
      @branch_id    = branch_id
    end

    def call
      invoices     = fetch_invoices
      credit_notes = fetch_credit_notes

      seller_state = seller_state_code

      # Classify every document into its GSTR-1 section.
      classified_invoices = invoices.group_by do |inv|
        Gst::Gstr1::SectionClassifier.invoice_section(inv, seller_state_code: seller_state)
      end

      classified_notes = credit_notes.group_by do |cn|
        Gst::Gstr1::SectionClassifier.credit_note_section(cn)
      end

      b2b_invoices  = classified_invoices[:b2b]   || []
      b2cl_invoices = classified_invoices[:b2cl]  || []
      b2cs_invoices = classified_invoices[:b2cs]  || []
      cdnr_notes    = classified_notes[:cdnr]     || []
      cdnur_notes   = classified_notes[:cdnur]    || []

      # Validate — non-blocking; errors surface in the result.
      validation = Gst::Gstr1::Validator.call(
        gstin:        @organization.gst_number,
        invoices:     invoices,
        credit_notes: credit_notes
      )

      Result.new(
        gstin:              @organization.gst_number,
        return_period:      @period_from.strftime('%m%Y'),
        period_from:        @period_from,
        period_to:          @period_to,
        seller_state_code:  seller_state,
        b2b_invoices:       b2b_invoices,
        b2cl_invoices:      b2cl_invoices,
        b2cs_invoices:      b2cs_invoices,
        cdnr_notes:         cdnr_notes,
        cdnur_notes:        cdnur_notes,
        validation_result:  validation
      )
    end

    private

    # ── Data fetching ────────────────────────────────────────────────────────────

    # FIX: include 'paid' and 'partially_paid' — previously only 'issued' was fetched.
    def fetch_invoices
      scope = SalesInvoice
        .where(organization: @organization)
        .where(status: FINALIZED_STATUSES)
        .where(invoice_date: @period_from..@period_to)
        .includes(:customer, :branch, lines: { product: :units_of_measure })

      scope = scope.where(branch_id: @branch_id) if @branch_id
      scope.to_a
    end

    def fetch_credit_notes
      scope = CreditNote
        .where(organization: @organization)
        .where(status: 'issued')
        .where(issued_at: @period_from.beginning_of_day..@period_to.end_of_day)
        .includes(:customer, :branch, lines: { product: :units_of_measure })

      scope = scope.where(branch_id: @branch_id) if @branch_id
      scope.to_a
    end

    # ── Seller state ─────────────────────────────────────────────────────────────

    def seller_state_code
      # If branch-scoped, use that branch's state. Otherwise use org's GSTIN prefix.
      if @branch_id
        branch = Branch.find_by(id: @branch_id, organization: @organization)
        branch&.state_code.presence
      end ||
        @organization.gst_number.to_s[0..1].presence ||
        '00'
    end
  end
end
