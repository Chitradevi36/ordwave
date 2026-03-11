# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 2 — Customer/Retailer code found in narration AND amount matches an open invoice
    # Score: 98 if code matches + exact invoice amount
    #        85 if code matches but amount doesn't align to one invoice
    class ExactRetailerCodeRule
      RULE_CODE = "exact_retailer_code"

      Candidate = Struct.new(:customer_id, :invoice_id, :score, :rule_code, :explanation, keyword_init: true)

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        code_tokens = @txn.match_meta&.dig("customer_codes") || []
        return [] if code_tokens.empty?

        candidates = []

        code_tokens.each do |code|
          customer = Customer
                       .where(organization: @org)
                       .where("UPPER(code) = ?", code.strip.upcase)
                       .first
          next unless customer

          open_invoices = SalesInvoice.for_org(@org).outstanding.by_customer(customer)

          # Try exact amount match on open invoices
          amount_match = open_invoices.find { |inv| inv.outstanding_amount.to_d == @txn.amount.to_d }

          if amount_match
            candidates << Candidate.new(
              customer_id: customer.id,
              invoice_id:  amount_match.id,
              score:       98.0,
              rule_code:   RULE_CODE,
              explanation: {
                matched_code:   code,
                customer_name:  customer.name,
                invoice_number: amount_match.invoice_number,
                amount:         @txn.amount,
                strategy:       "retailer_code_exact_amount"
              }
            )
          elsif open_invoices.any?
            # Code matched but no single-invoice amount match — lower confidence
            candidates << Candidate.new(
              customer_id: customer.id,
              invoice_id:  nil,
              score:       75.0,
              rule_code:   RULE_CODE,
              explanation: {
                matched_code:    code,
                customer_name:   customer.name,
                open_invoices:   open_invoices.count,
                strategy:        "retailer_code_no_amount_match"
              }
            )
          end
        end

        candidates
      end
    end
  end
end
