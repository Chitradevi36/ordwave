# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 7 — Customer trade name (or alias) appears in the narration,
    # AND the transaction amount is within TOLERANCE of an outstanding invoice
    # for that customer.
    #
    # Score:
    #   85  — narration contains customer name AND there is exactly one
    #          open invoice whose grand_total matches the amount
    #   78  — narration contains customer name AND there are multiple open
    #          invoices totalling the amount (ambiguous)
    #   70  — narration contains customer name but no single invoice amount
    #          match (customer-only signal)
    class ExactAmountCustomerNameRule
      RULE_CODE  = "exact_amount_customer_name"
      TOLERANCE  = 0.01
      MIN_TOKENS = 3   # Customer name tokens must be >= 3 chars to reduce noise

      Candidate = Struct.new(
        :customer_id, :invoice_id, :score, :rule_code, :explanation,
        keyword_init: true
      )

      def self.call(txn, org)
        new(txn, org).call
      end

      def initialize(txn, org)
        @txn = txn
        @org = org
      end

      def call
        return [] unless @txn.credit?
        return [] if (@txn.normalized_narration || "").empty?

        narration_tokens = @txn.normalized_narration
                               .upcase
                               .split(/\s+/)
                               .select { |t| t.length >= MIN_TOKENS }
                               .to_set

        return [] if narration_tokens.empty?

        customers = Customer.where(organization: @org)
                            .where("status = 'active' OR status IS NULL")
                            .select(:id, :trade_name, :name, :code)

        matched_customers = customers.select do |c|
          customer_tokens(c).any? { |t| narration_tokens.include?(t) }
        end

        return [] if matched_customers.empty?

        results = []

        matched_customers.each do |customer|
          open_invoices = SalesInvoice
                            .for_org(@org)
                            .outstanding
                            .where(customer: customer)
                            .limit(20)
                            .to_a

          # Try exact amount match
          amount_match = open_invoices.select do |inv|
            (inv.grand_total.to_d - @txn.amount.to_d).abs <= TOLERANCE
          end

          if amount_match.size == 1
            inv = amount_match.first
            results << Candidate.new(
              customer_id: customer.id,
              invoice_id:  inv.id,
              score:       85.0,
              rule_code:   RULE_CODE,
              explanation: {
                strategy:      "customer_name_in_narration_single_invoice_amount",
                customer_name: customer.trade_name || customer.name,
                invoice:       inv.invoice_number,
                amount:        @txn.amount
              }
            )
          elsif amount_match.size > 1
            results << Candidate.new(
              customer_id: customer.id,
              invoice_id:  nil,
              score:       78.0,
              rule_code:   RULE_CODE,
              explanation: {
                strategy:      "customer_name_in_narration_ambiguous_amount",
                customer_name: customer.trade_name || customer.name,
                matching_invoices: amount_match.map(&:invoice_number),
                amount:        @txn.amount
              }
            )
          else
            # Customer recognized but no invoice amount match
            results << Candidate.new(
              customer_id: customer.id,
              invoice_id:  nil,
              score:       70.0,
              rule_code:   RULE_CODE,
              explanation: {
                strategy:      "customer_name_in_narration_no_amount_match",
                customer_name: customer.trade_name || customer.name,
                open_invoice_count: open_invoices.size
              }
            )
          end
        end

        # Return highest-scoring match only
        results.sort_by { |c| -c.score }.first(3)
      end

      private

      # Build a set of significant tokens from the customer's known names
      def customer_tokens(customer)
        names = [
          customer.trade_name,
          customer.name,
          customer.code
        ].compact.map(&:upcase)

        names.flat_map { |name| name.split(/[\s\-_\/]+/) }
             .select { |t| t.length >= MIN_TOKENS }
      end
    end
  end
end
