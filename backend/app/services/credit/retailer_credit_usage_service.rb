module Credit
  # Computes credit consumption breakdown for a retailer (customer) in a branch.
  #
  # Credit Used = invoice_outstanding + order_exposure
  #
  # Definitions:
  #   invoice_outstanding  – current_balance on the credit account (manually maintained;
  #                          represents settled/invoiced outstanding from past deliveries).
  #   order_exposure       – sum of total_amount for submitted + approved orders
  #                          (committed pipeline; not yet reflected in current_balance).
  #   hold_exposure        – sum of on_hold orders (informational; shown to managers).
  #   credit_used_total    – invoice_outstanding + order_exposure
  #   available_credit     – max(credit_limit − credit_used_total, 0)
  #
  # Note: Draft, rejected, and cancelled orders MUST NOT consume credit.
  # There is no Invoice model yet; invoice_outstanding = current_balance.
  #
  # Usage (single retailer):
  #   result = Credit::RetailerCreditUsageService.call(retailer:, branch:)
  #
  # Usage (batch, for list pages — no N+1):
  #   map = Credit::RetailerCreditUsageService.batch(branch:, retailer_ids:)
  #   # => { retailer_id => { order_exposure:, hold_exposure: } }
  #
  class RetailerCreditUsageService
    # These statuses actively consume credit (confirmed pipeline commitments).
    EXPOSURE_STATUSES = %w[submitted approved].freeze

    # On-hold orders shown as a separate informational bucket.
    HOLD_STATUSES = %w[on_hold].freeze

    # Explicitly excluded from all credit consumption calculations.
    EXCLUDED_STATUSES = %w[draft rejected cancelled].freeze

    # ── Single retailer ────────────────────────────────────────────────────────

    def self.call(retailer:, branch:, on_date: Date.current)
      new(retailer: retailer, branch: branch, on_date: on_date).call
    end

    # ── Batch for list pages ───────────────────────────────────────────────────
    # Returns a Hash { retailer_id => { order_exposure: Float, hold_exposure: Float } }
    # Uses two GROUP BY queries — avoids N+1 regardless of page size.
    def self.batch(branch:, retailer_ids:)
      return {} if retailer_ids.blank?

      exposure_map = SalesOrder.not_deleted
                               .where(customer_id: retailer_ids, branch_id: branch.id)
                               .where(status: EXPOSURE_STATUSES)
                               .group(:customer_id)
                               .sum(:total_amount)
                               .transform_values(&:to_f)

      hold_map = SalesOrder.not_deleted
                           .where(customer_id: retailer_ids, branch_id: branch.id)
                           .where(status: HOLD_STATUSES)
                           .group(:customer_id)
                           .sum(:total_amount)
                           .transform_values(&:to_f)

      retailer_ids.each_with_object({}) do |rid, hash|
        hash[rid] = {
          order_exposure: exposure_map.fetch(rid, 0.0),
          hold_exposure:  hold_map.fetch(rid, 0.0),
        }
      end
    end

    # ── Instance ───────────────────────────────────────────────────────────────

    def initialize(retailer:, branch:, on_date: Date.current)
      @retailer = retailer
      @branch   = branch
      @on_date  = on_date
    end

    def call
      ca = @retailer.credit_account

      credit_limit        = ca&.credit_limit.to_f
      invoice_outstanding = ca&.current_balance.to_f

      exposure_scope        = base_orders.where(status: EXPOSURE_STATUSES)
      hold_scope            = base_orders.where(status: HOLD_STATUSES)
      order_exposure        = exposure_scope.sum(:total_amount).to_f
      hold_exposure         = hold_scope.sum(:total_amount).to_f
      orders_exposure_count = exposure_scope.count
      orders_hold_count     = hold_scope.count

      credit_used_total = invoice_outstanding + order_exposure
      available_credit  = [credit_limit - credit_used_total, 0.0].max

      # First 10 contributing orders (most recent first) for display in Credit tab
      contributing_orders = exposure_scope
                              .order(created_at: :desc)
                              .limit(10)
                              .pluck(:id, :order_number, :status, :total_amount, :created_at)
                              .map do |id, order_number, status, total_amount, created_at|
                                {
                                  id:           id,
                                  order_number: order_number,
                                  status:       status,
                                  total_amount: total_amount.to_f.round(2),
                                  created_at:   created_at.iso8601,
                                }
                              end

      {
        credit_limit:         credit_limit.round(2),
        invoice_outstanding:  invoice_outstanding.round(2),
        order_exposure:       order_exposure.round(2),
        hold_exposure:        hold_exposure.round(2),
        credit_used_total:    credit_used_total.round(2),
        available_credit:     available_credit.round(2),
        contributing_orders:  contributing_orders,
        breakdown: {
          orders_count_exposure:     orders_exposure_count,
          orders_count_hold:         orders_hold_count,
          invoices_count_outstanding: 0,  # No Invoice model yet; placeholder
        },
        debug: {
          computed_at:       Time.current.iso8601,
          excluded_statuses: EXCLUDED_STATUSES,
          included_statuses: EXPOSURE_STATUSES,
        },
      }
    end

    private

    def base_orders
      SalesOrder.not_deleted.where(customer_id: @retailer.id, branch_id: @branch.id)
    end
  end
end
