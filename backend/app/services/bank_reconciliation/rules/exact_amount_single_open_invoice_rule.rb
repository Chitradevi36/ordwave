# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 5 — There is exactly one open invoice in the org whose outstanding balance
    #          equals the transaction amount.
    # This is a last-resort rule — used only when no other signals are available.
    # Score: 90 if unique match; 50 if multiple invoices at same amount
    class ExactAmountSingleOpenInvoiceRule
      RULE_CODE = "exact_amount_single_open_invoice"

      Candidate = Struct.new(:customer_id, :invoice_id, :score, :rule_code, :explanation, keyword_init: true)

      MAX_SCAN_INVOICES = 500   # safety cap to avoid full-table scan on large orgs

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        # Fetch outstanding invoices where grand_total matches.
        # We use grand_total as a proxy for outstanding_amount here to stay within SQL.
        # The posting service will verify the exact outstanding_amount before posting.
        matching = SalesInvoice
                     .for_org(@org)
                     .outstanding
                     .where("grand_total = ?", @txn.amount)
                     .limit(MAX_SCAN_INVOICES)

        return [] if matching.none?

        if matching.count == 1
          inv = matching.first
          [Candidate.new(
            customer_id: inv.customer_id,
            invoice_id:  inv.id,
            score:       90.0,
            rule_code:   RULE_CODE,
            explanation: {
              invoice_number: inv.invoice_number,
              amount:         @txn.amount,
              strategy:       "exact_amount_unique_open_invoice"
            }
          )]
        else
          # Multiple invoices with same total — still useful as a weak signal
          [Candidate.new(
            customer_id: nil,
            invoice_id:  nil,
            score:       50.0,
            rule_code:   RULE_CODE,
            explanation: {
              matching_invoice_count: matching.count,
              amount:                 @txn.amount,
              strategy:               "exact_amount_ambiguous_multiple_invoices"
            }
          )]
        end
      end
    end
  end
end
