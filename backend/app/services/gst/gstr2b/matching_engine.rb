# frozen_string_literal: true

module Gst
  module Gstr2b
    # Matches GSTR-2B import lines against PurchaseInvoices within the organization's
    # purchase ledger and produces reconciliation issues for mismatches.
    #
    # Matching strategy (tiered):
    #   Tier 1 — Exact: supplier_gstin + invoice_number → confidence 1.0
    #   Tier 2 — Fuzzy number: same GSTIN, normalized invoice number match → 0.90
    #   Tier 3 — Loose: same GSTIN + taxable_value within ±2% + date within ±15 days → 0.70
    #
    # Usage:
    #   engine = Gst::Gstr2b::MatchingEngine.new(
    #     gst2b_import: import,
    #     organization: org
    #   )
    #   engine.run!
    #
    class MatchingEngine
      DATE_TOLERANCE_DAYS   = 15
      AMOUNT_TOLERANCE_PCT  = 0.02   # 2%
      TAX_TOLERANCE_AMOUNT  = 1.0    # ₹1 rounding tolerance

      def initialize(gst2b_import:, organization:)
        @import       = gst2b_import
        @organization = organization
      end

      def run!
        @import.mark_matching!

        # Pre-load all relevant purchase invoices into memory, indexed for fast lookup
        purchase_index = build_purchase_index

        lines = @import.gst2b_import_lines.where(match_status: 'pending').includes(:gst2b_import)

        lines.find_each do |line|
          match_line!(line, purchase_index)
        rescue StandardError => e
          Rails.logger.warn("[Gstr2b::MatchingEngine] Line #{line.id} error: #{e.message}")
        end

        @import.mark_completed!
      rescue StandardError => e
        @import.mark_failed!(e.message)
        raise
      end

      private

      # Index: { supplier_gstin => { normalized_invoice_number => [PurchaseInvoice] } }
      def build_purchase_index
        invoices = PurchaseInvoice.where(organization_id: @organization.id)
                     .where.not(supplier_gstin: [nil, ''])
                     .where(status: %w[received approved paid])

        index = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
        invoices.find_each do |inv|
          gstin = inv.supplier_gstin.upcase
          num   = normalize_invoice_number(inv.invoice_number)
          index[gstin][num] << inv
        end
        index
      end

      def match_line!(line, purchase_index)
        gstin        = line.supplier_gstin.upcase
        inv_num_norm = normalize_invoice_number(line.invoice_number)
        candidates   = purchase_index[gstin]

        # ── Tier 1: Exact match by normalized invoice number ─────────────────
        exact = candidates[inv_num_norm]
        if exact.length == 1
          pi = exact.first
          status, confidence = reconcile_amounts(line, pi)
          line.apply_match!(
            purchase_invoice: pi,
            confidence:       confidence,
            explanation:      "Tier-1 exact match (#{status})"
          )
          create_reconciliation_issue_if_needed!(line, pi, status)
          return
        elsif exact.length > 1
          line.update!(
            match_status:       'multiple_candidates',
            match_confidence:   0.85,
            match_explanation:  "#{exact.length} purchases match invoice '#{line.invoice_number}' for #{gstin}"
          )
          return
        end

        # ── Tier 2: Fuzzy invoice number (strip zeros, spaces, special chars) ──
        fuzzy_matches = candidates.select do |normalized_num, _|
          fuzzy_match?(inv_num_norm, normalized_num)
        end.values.flatten

        if fuzzy_matches.length == 1
          pi = fuzzy_matches.first
          status, _confidence = reconcile_amounts(line, pi)
          line.apply_match!(
            purchase_invoice: pi,
            confidence:       0.90,
            explanation:      "Tier-2 fuzzy number match (#{status})"
          )
          create_reconciliation_issue_if_needed!(line, pi, status)
          return
        end

        # ── Tier 3: Loose match (GSTIN + amount + date tolerance) ────────────
        all_for_gstin = candidates.values.flatten
        loose = all_for_gstin.select { |pi| loose_match?(line, pi) }

        if loose.length == 1
          pi = loose.first
          line.apply_match!(
            purchase_invoice: pi,
            confidence:       0.70,
            explanation:      "Tier-3 loose match (amount+date tolerance)"
          )
          create_reconciliation_issue_if_needed!(line, pi, :amount_warning)
          return
        end

        # ── No match ─────────────────────────────────────────────────────────
        line.mark_missing_in_books!
        create_missing_in_books_issue!(line)
      end

      # Returns [:ok | :tax_mismatch | :date_mismatch, confidence]
      def reconcile_amounts(line, purchase_invoice)
        tax_ok  = amounts_match?(line, purchase_invoice)
        date_ok = dates_match?(line, purchase_invoice)

        if !tax_ok
          [:tax_mismatch, 0.75]
        elsif !date_ok
          [:date_mismatch, 0.85]
        else
          [:ok, 1.0]
        end
      end

      def amounts_match?(line, pi)
        books_tax = pi.total_tax_amount.to_d
        portal_tax = ((line.igst || 0) + (line.cgst || 0) + (line.sgst || 0)).to_d
        (books_tax - portal_tax).abs <= TAX_TOLERANCE_AMOUNT
      end

      def dates_match?(line, pi)
        return true if line.invoice_date.nil? || pi.invoice_date.nil?
        (line.invoice_date.to_date - pi.invoice_date.to_date).abs <= DATE_TOLERANCE_DAYS
      end

      def loose_match?(line, pi)
        return false if pi.taxable_value.to_d.zero?
        amount_close = (line.taxable_value.to_d - pi.taxable_value.to_d).abs /
                       pi.taxable_value.to_d <= AMOUNT_TOLERANCE_PCT
        amount_close && dates_match?(line, pi)
      end

      def fuzzy_match?(a, b)
        return false if a.blank? || b.blank?
        a_clean = a.gsub(/[^A-Z0-9]/, '')
        b_clean = b.gsub(/[^A-Z0-9]/, '')
        a_clean == b_clean || a_clean.end_with?(b_clean) || b_clean.end_with?(a_clean)
      end

      def normalize_invoice_number(num)
        return '' if num.blank?
        num.upcase.gsub(/\s+/, '').strip
      end

      # ── Issue creation ────────────────────────────────────────────────────────

      def create_reconciliation_issue_if_needed!(line, purchase_invoice, status)
        return if status == :ok

        issue_type = case status
                     when :tax_mismatch    then 'tax_mismatch'
                     when :date_mismatch   then 'date_mismatch'
                     when :amount_warning  then 'invoice_value_mismatch'
                     end

        return unless issue_type

        books_tax   = purchase_invoice.total_tax_amount.to_d
        portal_tax  = ((line.igst || 0) + (line.cgst || 0) + (line.sgst || 0)).to_d

        GstReconciliationIssue.create!(
          organization:       @organization,
          gst2b_import:       @import,
          issue_type:         issue_type,
          severity:           issue_type == 'tax_mismatch' ? 'high' : 'medium',
          source_type:        'Gst2bImportLine',
          source_id:          line.id,
          counterpart_type:   'PurchaseInvoice',
          counterpart_id:     purchase_invoice.id,
          supplier_gstin:     line.supplier_gstin,
          invoice_number:     line.invoice_number,
          invoice_date:       line.invoice_date,
          amount_books:       books_tax,
          amount_portal:      portal_tax,
          difference_amount:  (books_tax - portal_tax).abs,
          status:             'open'
        )
      end

      def create_missing_in_books_issue!(line)
        GstReconciliationIssue.create!(
          organization:     @organization,
          gst2b_import:     @import,
          issue_type:       'missing_in_books',
          severity:         line.itc_available ? 'high' : 'medium',
          source_type:      'Gst2bImportLine',
          source_id:        line.id,
          supplier_gstin:   line.supplier_gstin,
          invoice_number:   line.invoice_number,
          invoice_date:     line.invoice_date,
          amount_portal:    ((line.igst || 0) + (line.cgst || 0) + (line.sgst || 0)).to_d,
          status:           'open'
        )
      end
    end
  end
end
