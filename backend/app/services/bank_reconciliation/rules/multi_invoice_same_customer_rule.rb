# frozen_string_literal: true

module BankReconciliation
  module Rules
    # Rule 6 — Multiple open invoices for the same customer add up to the
    # transaction amount (within ₹0.01 tolerance).
    #
    # Score: 88 when the combination is unique (only one permutation of
    # invoices sums to the amount). Score: 72 if multiple combos exist.
    #
    # Limits:
    #   - Considers up to MAX_INVOICES_PER_CUSTOMER open invoices per customer
    #   - Considers combinations of 2 to MAX_COMBO_SIZE invoices
    #   - Caps search at MAX_CUSTOMERS_SCANNED to avoid full-table scans
    class MultiInvoiceSameCustomerRule
      RULE_CODE = "multi_invoice_same_customer"

      MAX_INVOICES_PER_CUSTOMER = 20
      MAX_COMBO_SIZE            = 4
      MAX_CUSTOMERS_SCANNED     = 200
      TOLERANCE                 = 0.01

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
        # Only run for credits
        return [] unless @txn.credit?

        target = @txn.amount.to_d

        # Narrow: if we have a customer signal, limit to that customer only
        hinted_customer_id = @txn.matched_customer_id ||
                             @txn.candidates.order(score: :desc).first&.customer_id

        customers_to_check = if hinted_customer_id
          Customer.where(id: hinted_customer_id)
        else
          Customer.joins(:sales_invoices)
                  .where(sales_invoices: { organization_id: @org.id })
                  .where("sales_invoices.status IN (?)", %w[unpaid partially_paid])
                  .distinct
                  .limit(MAX_CUSTOMERS_SCANNED)
        end

        results = []

        customers_to_check.each do |customer|
          invoices = SalesInvoice
                       .for_org(@org)
                       .outstanding
                       .where(customer: customer)
                       .order(grand_total: :asc)
                       .limit(MAX_INVOICES_PER_CUSTOMER)
                       .to_a

          next if invoices.size < 2

          matching_combos = find_combinations(invoices, target)
          next if matching_combos.empty?

          best_combo   = matching_combos.first
          score        = matching_combos.size == 1 ? 88.0 : 72.0
          invoice_ids  = best_combo.map(&:id)
          invoice_nums = best_combo.map(&:invoice_number)

          # Emit one candidate per invoice in the combo — the PostingService
          # handles the multi-invoice allocation. We flag all with same group.
          best_combo.each_with_index do |inv, idx|
            results << Candidate.new(
              customer_id: customer.id,
              invoice_id:  inv.id,
              score:       score,
              rule_code:   RULE_CODE,
              explanation: {
                strategy:          "multi_invoice_combination",
                combo_size:        best_combo.size,
                total_of_combo:    best_combo.sum { |i| i.grand_total.to_d }.to_f,
                transaction_amount: target.to_f,
                invoice_numbers:   invoice_nums,
                all_invoice_ids:   invoice_ids,
                this_invoice_index: idx,
                ambiguous:         matching_combos.size > 1
              }
            )
          end
        end

        # Keep at most the highest-scoring customer group
        results
          .group_by(&:customer_id)
          .values
          .max_by { |group| group.first.score }
          &.flatten || []
      end

      private

      # Returns all combinations of size 2..MAX_COMBO_SIZE whose grand_totals
      # sum within TOLERANCE of the target.
      def find_combinations(invoices, target)
        matching = []

        (2..MAX_COMBO_SIZE).each do |combo_size|
          break if invoices.size < combo_size

          invoices.combination(combo_size) do |combo|
            combo_total = combo.sum { |i| i.grand_total.to_d }
            matching << combo if (combo_total - target).abs <= TOLERANCE
          end

          # Short-circuit: if we already found matches at this size, don't grow
          break if matching.any?
        end

        matching
      end
    end
  end
end
