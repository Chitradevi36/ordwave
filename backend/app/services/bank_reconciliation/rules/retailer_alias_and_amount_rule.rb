# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 4 — Narration tokens match a CustomerAlias AND exactly one open invoice balance
    #          equals the transaction amount.
    # Score:  95 — strong fuzzy match
    class RetailerAliasAndAmountRule
      RULE_CODE = "retailer_alias_and_amount"

      Candidate = Struct.new(:customer_id, :invoice_id, :score, :rule_code, :explanation, keyword_init: true)

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        tokens = @txn.match_meta&.dig("tokens") || []
        return [] if tokens.length < 2

        candidates = []
        matched_customers = Set.new

        tokens.each do |token|
          next if token.length < 3

          # Search aliases
          aliases = CustomerAlias
                      .for_org(@org)
                      .where("UPPER(alias_name) LIKE ?", "%#{token}%")
          aliases.each do |ca|
            next if matched_customers.include?(ca.customer_id)
            matched_customers.add(ca.customer_id)
          end

          # Also fuzzy-match against customer name directly
          Customer
            .where(organization: @org)
            .where("UPPER(name) LIKE ?", "%#{token}%")
            .each do |c|
              matched_customers.add(c.id)
            end
        end

        # Only proceed when exactly ONE customer identified — ambiguity drops confidence
        if matched_customers.size == 1
          customer_id   = matched_customers.first
          open_invoices = SalesInvoice
                            .for_org(@org)
                            .outstanding
                            .where(customer_id: customer_id)
          amount_match  = open_invoices.find { |i| i.outstanding_amount.to_d == @txn.amount.to_d }

          if amount_match
            candidates << Candidate.new(
              customer_id: customer_id,
              invoice_id:  amount_match.id,
              score:       95.0,
              rule_code:   RULE_CODE,
              explanation: {
                matched_tokens:  tokens.first(5),
                invoice_number:  amount_match.invoice_number,
                amount:          @txn.amount,
                strategy:        "alias_fuzzy_exact_amount"
              }
            )
          end
        elsif matched_customers.size > 1
          # Multiple customers matched — too ambiguous for high score
          candidates << Candidate.new(
            customer_id: nil,
            invoice_id:  nil,
            score:       40.0,
            rule_code:   RULE_CODE,
            explanation: {
              matched_customer_ids: matched_customers.to_a,
              strategy:             "alias_ambiguous_multiple_customers"
            }
          )
        end

        candidates
      end
    end
  end
end
