module Credit
  # Lightweight wrapper to evaluate an order's credit impact without side-effects.
  # Returns a hash with :decision, :reasons and :metrics (merged with usage metrics)
  class PrecheckService
    def self.call(credit_account:, product_ids: [], order_total: 0.0, branch:, on_date: Date.current)
      new(credit_account: credit_account, product_ids: product_ids, order_total: order_total, branch: branch, on_date: on_date).call
    end

    def initialize(credit_account:, product_ids:, order_total:, branch:, on_date:)
      @credit_account = credit_account
      @product_ids    = Array(product_ids)
      @order_total    = order_total.to_f
      @branch         = branch
      @on_date        = on_date
    end

    def call
      return default_ok unless @credit_account

      result = Credit::CreditEngine.evaluate_order(
        credit_account: @credit_account,
        product_ids:    @product_ids,
        order_total:    @order_total,
        on_date:        @on_date
      )

      usage = Credit::RetailerCreditUsageService.call(
        retailer: @credit_account.customer,
        branch:   @branch
      )

      result[:metrics] = result[:metrics].merge(
        order_exposure:      usage[:order_exposure],
        invoice_outstanding: usage[:invoice_outstanding],
        available_credit:    usage[:available_credit],
        credit_used_total:   usage[:credit_used_total],
        hold_exposure:       usage[:hold_exposure]
      )

      result
    end

    private

    def default_ok
      { decision: Credit::CreditEngine::DECISION_OK, reasons: [], metrics: {} }
    end
  end
end
