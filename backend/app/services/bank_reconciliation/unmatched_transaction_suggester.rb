# frozen_string_literal: true

module BankReconciliation
  # Provides intelligent suggestions for unmatched bank transactions
  # Helps finance team quickly match or categorize unmatched amounts
  #
  # Usage:
  #   suggester = BankReconciliation::UnmatchedTransactionSuggester.new(
  #     bank_transaction: txn,
  #     organization: org
  #   )
  #   suggestions = suggester.get_suggestions
  #   # Returns:
  #   # [
  #   #   { type: 'exact_invoice_match', confidence: 100, invoice: ..., amount: X },
  #   #   { type: 'similar_amount', confidence: 85, reference: '...', amount: X },
  #   #   { type: 'customer_pattern', confidence: 70, customer: ..., recent_avg: X },
  #   # ]
  #
  class UnmatchedTransactionSuggester
    def initialize(bank_transaction:, organization:)
      @txn = bank_transaction
      @org = organization
    end

    def get_suggestions
      suggestions = []

      # 1. Exact amount match to unpaid invoice
      suggestions.concat(exact_invoice_matches)

      # 2. Similar amount to recent transactions (within 5%)
      suggestions.concat(similar_amount_matches)

      # 3. Customer payment pattern detection
      suggestions.concat(customer_pattern_suggestions)

      # 4. Advance payment detection (round amounts)
      suggestions.concat(advance_payment_suggestions)

      suggestions.sort_by { |s| -s[:confidence] }.first(3) # Top 3 suggestions
    end

    private

    def exact_invoice_matches
      # Look for unpaid invoices matching exact amount
      invoices = @org.sales_invoices
                      .where(status: %w[due overdue])
                      .where("total_amount = ?", @txn.amount)
                      .order(due_date: :asc)
                      .limit(3)

      invoices.map do |inv|
        {
          type: 'exact_invoice_match',
          confidence: 100,
          invoice_id: inv.id,
          invoice_number: inv.invoice_number,
          customer_id: inv.customer_id,
          customer_name: inv.customer.name,
          amount: inv.total_amount,
          customer_email: inv.customer.email,
          action: 'approve_match',
          reason: "Invoice #{inv.invoice_number} for ₹#{inv.total_amount} is unpaid"
        }
      end
    end

    def similar_amount_matches
      # Look for transactions within 5% of this amount (common payment rounding)
      tolerance = (@txn.amount * 0.05).round(2)
      min_amount = @txn.amount - tolerance
      max_amount = @txn.amount + tolerance

      recent_txns = @org.bank_transactions
                         .where("amount BETWEEN ? AND ?", min_amount, max_amount)
                         .where.not(id: @txn.id)
                         .where.not(status: %w[unmatched])
                         .order(txn_date: :desc)
                         .includes(:matched_customer)
                         .limit(3)

      recent_txns.map do |similar|
        difference = ((similar.amount - @txn.amount) / @txn.amount * 100).abs.round(1)
        {
          type: 'similar_amount',
          confidence: (100 - difference * 2).to_i.clamp(60, 95),
          reference_number: similar.reference_number,
          narration: similar.narration,
          similar_txn_date: similar.txn_date,
          matched_customer_id: similar.matched_customer_id,
          matched_customer_name: similar.matched_customer&.name,
          amount_difference: difference,
          action: 'assign_as_advance',
          reason: "Similar amount (₹#{similar.amount}) was matched as #{similar.status}"
        }
      end
    end

    def customer_pattern_suggestions
      # Detect if this could be a payment from a known customer based on patterns
      recent_payments = @org.payments
                            .where(direction: 'received')
                            .order(received_date: :desc)
                            .limit(100)

      customer_patterns = recent_payments.group_by(&:customer_id).map do |cust_id, payments|
        avg_amount = payments.map(&:amount).sum / payments.count.to_f
        max_amount = payments.map(&:amount).max
        min_amount = payments.map(&:amount).min

        is_typical = @txn.amount.between?(min_amount * 0.8, max_amount * 1.2)

        {
          customer_id: cust_id,
          customer_name: payments.first.customer.name,
          avg_amount: avg_amount,
          payments_count: payments.count,
          is_typical_amount: is_typical,
          confidence: is_typical ? 75 : 45
        }
      end

      # Filter to likely candidates
      customer_patterns
        .select { |p| p[:is_typical_amount] }
        .sort_by { |p| -p[:payments_count] } # Frequent payers first
        .first(2)
        .map do |pattern|
          {
            type: 'customer_pattern',
            confidence: pattern[:confidence],
            customer_id: pattern[:customer_id],
            customer_name: pattern[:customer_name],
            avg_payment: pattern[:avg_amount],
            payment_frequency: pattern[:payments_count],
            action: 'assign_to_customer',
            reason: "This customer has #{pattern[:payments_count]} similar payments in past 90 days"
          }
        end
    end

    def advance_payment_suggestions
      # Round numbers often indicate advance payments (₹5000, ₹10000)
      # Check if amount is round and customer commonly makes advances
      return [] unless round_number?(@txn.amount)

      customers_with_advances = @org.advance_payments
                                      .where(status: 'active')
                                      .group(:customer_id)
                                      .count
                                      .to_a
                                      .sort_by { |_, count| -count }
                                      .first(3)
                                      .map(&:first)

      # Filter to customers that make advances frequently
      advance_customers = @org.customers
                               .where(id: customers_with_advances)
                               .includes(:latest_payment)

      advance_customers.map do |customer|
        {
          type: 'advance_payment',
          confidence: 70,
          customer_id: customer.id,
          customer_name: customer.name,
          typical_advance: 5000, # Could be smarter here
          action: 'mark_as_advance',
          reason: "Round amount (₹#{@txn.amount}); #{customer.name} typically uses advances"
        }
      end
    end

    def round_number?(amount)
      # Check if amount is a "round" number (ends in 00 or 000)
      (amount % 100).zero? && amount > 1000
    end
  end
end
