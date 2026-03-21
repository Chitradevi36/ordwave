# frozen_string_literal: true

module BankReconciliation
  # Fetches unmatched transactions with intelligent grouping and suggestions
  # for the dashboard queue
  #
  # Usage:
  #   queue = BankReconciliation::UnmatchedQueueQuery.call(
  #     organization: org,
  #     bank_account_id: account.id,
  #     date_from: 7.days.ago,
  #     date_to: Date.today,
  #     limit: 25
  #   )
  #   queue.transactions # Array of matched transactions with suggestions
  #   queue.total_count  # Total unmatched in org
  #   queue.total_amount # Total $ unmatched
  #
  class UnmatchedQueueQuery
    Result = Struct.new(:transactions, :total_count, :total_amount, :oldest_date, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, bank_account_id: nil, date_from: nil, date_to: nil, limit: 25)
      @org = organization
      @bank_account_id = bank_account_id
      @date_from = date_from || 30.days.ago
      @date_to = date_to || Date.today
      @limit = limit
    end

    def call
      # Fetch unmatched transactions with candidates
      txns = @org.bank_transactions
                  .where(status: 'unmatched')
                  .where("txn_date >= ? AND txn_date <= ?", @date_from, @date_to)
                  .includes(:matched_customer, candidates: %i[customer sales_invoice])
                  .order(txn_date: :desc)

      txns = txns.where(bank_account_id: @bank_account_id) if @bank_account_id.present?

      # Get stats
      all_unmatched = @org.bank_transactions.where(status: 'unmatched')
      total_count = all_unmatched.count
      total_amount = all_unmatched.sum(:amount) || 0
      oldest_date = all_unmatched.order(:txn_date).first&.txn_date || Date.today

      # Paginate
      paginated = txns.page(1).per(@limit)

      # Enrich with suggestions
      enriched_txns = paginated.map do |txn|
        suggester = UnmatchedTransactionSuggester.new(
          bank_transaction: txn,
          organization: @org
        )

        {
          id: txn.id,
          bank_account_id: txn.bank_account_id,
          txn_date: txn.txn_date,
          amount: txn.amount,
          direction: txn.direction,
          narration: txn.narration,
          utr_number: txn.utr_number,
          reference_number: txn.reference_number,
          created_at: txn.created_at,
          days_unmatched: (Date.today - txn.txn_date.to_date).to_i,
          candidates: txn.candidates.map do |c|
            {
              id: c.id,
              customer_id: c.customer_id,
              customer_name: c.customer&.name,
              invoice_id: c.sales_invoice_id,
              invoice_number: c.sales_invoice&.invoice_number,
              score: c.score,
              rule_code: c.rule_code,
              selected: c.selected
            }
          end,
          suggestions: suggester.get_suggestions
        }
      end

      Result.new(
        transactions: enriched_txns,
        total_count: total_count,
        total_amount: total_amount,
        oldest_date: oldest_date
      )
    end
  end
end
