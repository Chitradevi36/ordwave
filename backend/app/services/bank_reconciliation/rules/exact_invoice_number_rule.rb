# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 1 — Invoice number found verbatim in narration
    # Score: 100 (highest confidence — invoice number is unambiguous)
    class ExactInvoiceNumberRule
      RULE_CODE = "exact_invoice_number"

      Candidate = Struct.new(:customer_id, :invoice_id, :score, :rule_code, :explanation, keyword_init: true)

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        invoice_tokens = @txn.match_meta&.dig("invoice_numbers") || []
        return [] if invoice_tokens.empty?

        candidates = []
        invoice_tokens.each do |token|
          invoice = SalesInvoice
                      .for_org(@org)
                      .outstanding
                      .where("UPPER(invoice_number) = ?", token.upcase)
                      .first
          next unless invoice

          candidates << Candidate.new(
            customer_id: invoice.customer_id,
            invoice_id:  invoice.id,
            score:       100.0,
            rule_code:   RULE_CODE,
            explanation: {
              matched_token:  token,
              invoice_number: invoice.invoice_number,
              invoice_amount: invoice.grand_total,
              strategy:       "exact_invoice_number_in_narration"
            }
          )
        end

        candidates
      end
    end
  end
end
