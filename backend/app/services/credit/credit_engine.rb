module Credit
  # Evaluates whether an order can proceed for a given credit account.
  #
  # Usage:
  #   result = Credit::CreditEngine.evaluate_order(
  #     credit_account: account,
  #     product_ids:    [1, 2, 3],
  #     order_total:    1500.0,
  #     on_date:        Date.current
  #   )
  #   result[:decision]  # => "ok" | "hold" | "blocked"
  #   result[:reasons]   # => []
  #   result[:metrics]   # => { available: ..., overdue_days: ... }
  class CreditEngine
    DECISION_OK      = 'ok'.freeze
    DECISION_HOLD    = 'hold'.freeze
    DECISION_BLOCKED = 'blocked'.freeze

    def self.evaluate_order(credit_account:, product_ids: [], order_total: 0, on_date: Date.current)
      new(
        credit_account: credit_account,
        product_ids:    product_ids,
        order_total:    order_total,
        on_date:        on_date
      ).evaluate
    end

    def initialize(credit_account:, product_ids:, order_total:, on_date:)
      @account      = credit_account
      @product_ids  = Array(product_ids)
      @order_total  = order_total.to_f
      @on_date      = on_date
      @policy       = CreditPolicy.for_org!(@account.organization)
      @reasons      = []
      @actions      = {}
    end

    def evaluate
      decision = compute_decision
      {
        decision: decision,
        reasons:  @reasons,
        metrics:  build_metrics,
        actions_required: @actions
      }
    end

    private

    def compute_decision
      # 1. Hard block — overdue >= hard_block_overdue_days
      if overdue_days >= @policy.hard_block_overdue_days
        @reasons << "Overdue by #{overdue_days} days (threshold: #{@policy.hard_block_overdue_days})"
        return DECISION_BLOCKED
      end

      # 2. Hard block — outstanding exceeds credit limit by margin
      if outstanding_exceeds_margin?
        @reasons << "Outstanding #{format_currency(outstanding)} exceeds #{@policy.hard_block_margin_pct}% above " \
                    "credit limit #{format_currency(@account.credit_limit)}"
        return DECISION_BLOCKED
      end

      # 3. Per-product prepayment required
      prepayment_products = prepayment_required_products
      unless prepayment_products.empty?
        @reasons << "Product(s) #{prepayment_products.join(', ')} require prepayment"
        @actions[:prepayment_required] = prepayment_products
        return DECISION_BLOCKED
      end

      # 4. Soft hold — overdue in soft-hold band
      if overdue_in_soft_hold_band?
        @reasons << "Overdue #{overdue_days} days falls within soft-hold band " \
                    "(#{@policy.soft_hold_overdue_days_min}–#{@policy.soft_hold_overdue_days_max})"
        return DECISION_HOLD
      end

      # 5. Soft hold — outstanding pct
      if outstanding_pct >= @policy.soft_hold_outstanding_pct
        @reasons << "Outstanding #{format_currency(outstanding)} is #{outstanding_pct.round(1)}% of " \
                    "credit limit #{format_currency(@account.credit_limit)}"
        return DECISION_HOLD
      end

      # 6. Collection-first flag
      if @account.collection_first?
        @reasons << 'Account flagged: collection first'
        @actions[:collection_required] = true
        return DECISION_HOLD
      end

      # 7. Hold required flag
      if @account.hold_required?
        @reasons << 'Account flagged: hold required'
        return DECISION_HOLD
      end

      DECISION_OK
    end

    def overdue_days
      @overdue_days ||= @account.overdue_days.to_i
    end

    def outstanding
      @outstanding ||= @account.outstanding_amount.to_f
    end

    def outstanding_pct
      return 0.0 if @account.credit_limit.to_f.zero?
      (outstanding / @account.credit_limit.to_f) * 100
    end

    def outstanding_exceeds_margin?
      return false if @account.credit_limit.to_f.zero?
      outstanding > @account.credit_limit.to_f * (1 + @policy.hard_block_margin_pct.to_f / 100)
    end

    def overdue_in_soft_hold_band?
      overdue_days.between?(@policy.soft_hold_overdue_days_min, @policy.soft_hold_overdue_days_max)
    end

    def prepayment_required_products
      return [] if @product_ids.empty?
      branch_id = @account.branch_id
      PrepaymentSku
        .active
        .for_org(@account.organization_id)
        .effective(@on_date)
        .where(product_id: @product_ids)
        .where('branch_id IS NULL OR branch_id = ?', branch_id)
        .pluck(:product_id)
    end

    def build_metrics
      {
        credit_limit:       @account.credit_limit,
        outstanding:        outstanding,
        available:          [@account.credit_limit.to_f - outstanding, 0].max,
        overdue_days:       overdue_days,
        overdue_bucket:     @account.overdue_bucket,
        outstanding_pct:    outstanding_pct.round(2),
        order_total:        @order_total
      }
    end

    def format_currency(val)
      "₹#{val.round(2)}"
    end
  end
end
