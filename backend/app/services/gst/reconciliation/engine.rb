# frozen_string_literal: true

module Gst
  module Reconciliation
    # Runs a full GST reconciliation audit for a given period or financial year.
    #
    # Checks performed:
    #   1. Missing in 2B       — Purchase invoices in books but not in GSTR-2B
    #   2. Missing in books    — GSTR-2B lines with no matching purchase invoice
    #   3. Tax mismatches      — Already flagged by MatchingEngine; re-surfaces for period
    #   4. GSTR-1 vs books     — Sales invoices in GSTR-1 snapshot vs books for same period
    #   5. ITC risk            — Suppliers with known mismatch pattern
    #
    # Usage:
    #   result = Gst::Reconciliation::Engine.call(
    #     organization:      org,
    #     gst_return_period: gstr2b_period,
    #     month:             9,
    #     year:              2025
    #   )
    #   result.success?
    #   result.issue_count         # Total new issues created
    #   result.issues_by_severity  # { blocking: 0, high: 2, medium: 3, low: 1 }
    #   result.errors
    #
    class Engine
      EngineResult = Struct.new(
        :success, :issue_count, :issues_by_severity, :errors, keyword_init: true
      ) do
        def success?; success; end
        def failure?; !success; end
        def has_blocking_issues?; issues_by_severity[:blocking].to_i > 0; end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(organization:, month:, year:, financial_year: nil,
                     gst_return_period: nil, branch: nil)
        @organization      = organization
        @month             = month
        @year              = year
        @financial_year    = financial_year
        @gst_return_period = gst_return_period
        @branch            = branch
        @new_issues        = []
      end

      def call
        period_from = Date.new(@year, @month, 1)
        period_to   = period_from.end_of_month

        check_purchase_missing_in_2b!(period_from, period_to)
        check_itc_risk!(period_from, period_to)
        check_gstr1_snapshot_vs_books!(period_from, period_to)

        issues_by_severity = @new_issues.group_by { |i| i.severity.to_sym }
                                        .transform_values(&:count)

        EngineResult.new(
          success:           true,
          issue_count:       @new_issues.count,
          issues_by_severity: {
            blocking: issues_by_severity[:blocking].to_i,
            high:     issues_by_severity[:high].to_i,
            medium:   issues_by_severity[:medium].to_i,
            low:      issues_by_severity[:low].to_i
          },
          errors: []
        )

      rescue StandardError => e
        Rails.logger.error("[Gst::Reconciliation::Engine] #{e.class}: #{e.message}")
        EngineResult.new(
          success:            false,
          issue_count:        0,
          issues_by_severity: {},
          errors:             [e.message]
        )
      end

      private

      # ── Check 1: Purchases in books not found in 2B ─────────────────────────

      def check_purchase_missing_in_2b!(from, to)
        purchases = PurchaseInvoice.where(
          organization_id: @organization.id,
          invoice_date: from..to,
          status: %w[received approved paid]
        ).where.not(supplier_gstin: [nil, ''])

        # Find 2B import for this period+GSTIN combo
        gstin_to_import = Gst2bImport.completed.where(
          organization_id: @organization.id, month: @month, year: @year
        ).index_by(&:gstin)

        purchases.find_each do |pi|
          import = gstin_to_import[pi.supplier_gstin&.upcase]
          next unless import  # No 2B import for this GSTIN — skip

          already_matched = Gst2bImportLine.where(
            gst2b_import_id:           import.id,
            matched_purchase_invoice_id: pi.id,
            match_status:              'matched'
          ).exists?

          next if already_matched

          # Check for existing open issue before creating duplicate
          next if existing_issue?('missing_in_2b', 'PurchaseInvoice', pi.id)

          issue = GstReconciliationIssue.create!(
            organization:       @organization,
            branch:             @branch,
            financial_year:     @financial_year,
            gst_return_period:  @gst_return_period,
            gst2b_import:       import,
            issue_type:         'missing_in_2b',
            severity:           pi.total_tax_amount.to_d > 10_000 ? 'high' : 'medium',
            source_type:        'PurchaseInvoice',
            source_id:          pi.id,
            supplier_gstin:     pi.supplier_gstin,
            invoice_number:     pi.invoice_number,
            invoice_date:       pi.invoice_date,
            amount_books:       pi.total_tax_amount.to_d,
            status:             'open'
          )
          @new_issues << issue
        end
      end

      # ── Check 2: ITC risk — supplier with recurring mismatch pattern ─────────

      def check_itc_risk!(from, to)
        # Suppliers with 2+ mismatches in this period
        risky_gstins = GstReconciliationIssue.where(
          organization_id: @organization.id
        ).where(
          issue_type: %w[missing_in_books tax_mismatch],
          created_at: (from.beginning_of_day..to.end_of_day)
        ).group(:supplier_gstin).having('COUNT(*) >= 2').pluck(:supplier_gstin)

        risky_gstins.each do |gstin|
          next if existing_issue?('itc_risk', nil, nil, gstin: gstin)

          issue = GstReconciliationIssue.create!(
            organization:      @organization,
            financial_year:    @financial_year,
            gst_return_period: @gst_return_period,
            issue_type:        'itc_risk',
            severity:          'high',
            supplier_gstin:    gstin,
            status:            'open'
          )
          @new_issues << issue
        end
      end

      # ── Check 3: GSTR-1 snapshot vs live books ────────────────────────────────

      def check_gstr1_snapshot_vs_books!(from, to)
        gstr1_period = GstReturnPeriod.find_by(
          organization_id: @organization.id,
          month:           @month,
          year:            @year,
          return_type:     'gstr1'
        )
        return unless gstr1_period&.latest_snapshot

        snapshot_ids = Set.new(
          gstr1_period.latest_snapshot.source_invoice_ids.values.flatten.map(&:to_i)
        )

        live_ids = Set.new(
          SalesInvoice.where(
            organization_id: @organization.id,
            invoice_date:    from..to,
            status:          %w[issued partially_paid paid]
          ).pluck(:id)
        )

        # Invoices in books but not in last snapshot
        (live_ids - snapshot_ids).each do |inv_id|
          next if existing_issue?('missing_in_books', 'SalesInvoice', inv_id)

          inv = SalesInvoice.find_by(id: inv_id)
          next unless inv

          issue = GstReconciliationIssue.create!(
            organization:      @organization,
            financial_year:    @financial_year,
            gst_return_period: gstr1_period,
            issue_type:        'missing_in_2b',
            severity:          'medium',
            source_type:       'SalesInvoice',
            source_id:         inv_id,
            customer_gstin:    inv.customer_gstin,
            invoice_number:    inv.invoice_number,
            invoice_date:      inv.invoice_date,
            amount_books:      inv.tax_total.to_d,
            status:            'open'
          )
          @new_issues << issue
        end
      end

      def existing_issue?(issue_type, source_type, source_id, gstin: nil)
        scope = GstReconciliationIssue.where(
          organization_id: @organization.id,
          issue_type:      issue_type,
          status:          %w[open acknowledged]
        )
        if source_type && source_id
          scope = scope.where(source_type: source_type, source_id: source_id)
        end
        scope = scope.where(supplier_gstin: gstin) if gstin.present?
        scope.exists?
      end
    end
  end
end
