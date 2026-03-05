# frozen_string_literal: true

module Analytics
  class CreditRiskQuery < BaseQuery
    attr_reader :sales_rep_id

    def initialize(organization:, branch_id: nil, sales_rep_id: nil)
      super(organization: organization, branch_id: branch_id)
      @sales_rep_id = sales_rep_id.presence&.to_i
    end

    # High-level counters for stat cards
    def summary
      base = credit_accounts_base

      {
        total_accounts:  base.count,
        risky_count:     base.where(risky_condition).count,
        blocked_count:   base.where(hold_required: true).count,
        watchlist_count: base.where(watchlist: true).count,
        total_overdue:   base.sum(:overdue_amount).to_d,
        total_exposure:  base.sum(:current_balance).to_d,
      }
    end

    # Aging bucket breakdown (counts) using overdue_days
    def aging_buckets
      base = credit_accounts_base

      {
        current:    base.where(overdue_days: [nil, 0]).count,
        d1_15:      base.where(overdue_days: 1..15).count,
        d16_30:     base.where(overdue_days: 16..30).count,
        d31_60:     base.where(overdue_days: 31..60).count,
        over_60:    base.where("overdue_days > 60").count,
      }
    end

    # Flat list of risky retailer accounts with customer info
    def risky_retailers
      credit_accounts_base
        .where(risky_condition)
        .joins(:customer)
        .select(
          "credit_accounts.id",
          "credit_accounts.customer_id",
          "customers.name AS customer_name",
          "customers.code AS customer_code",
          "credit_accounts.credit_limit",
          "credit_accounts.current_balance",
          "credit_accounts.available_credit",
          "credit_accounts.overdue_amount",
          "credit_accounts.overdue_days",
          "credit_accounts.hold_required",
          "credit_accounts.watchlist",
          "credit_accounts.overdue_bucket_cached",
          "CASE WHEN credit_accounts.credit_limit > 0 THEN ROUND(credit_accounts.current_balance::numeric / credit_accounts.credit_limit * 100, 1) ELSE 0 END AS utilization_pct"
        )
        .order(overdue_amount: :desc)
        .map do |r|
          {
            id:                r.id,
            customer_id:       r.customer_id,
            customer_name:     r["customer_name"],
            customer_code:     r["customer_code"],
            credit_limit:      r.credit_limit.to_d,
            current_balance:   r.current_balance.to_d,
            available_credit:  r.available_credit.to_d,
            overdue_amount:    r.overdue_amount.to_d,
            overdue_days:      r.overdue_days.to_i,
            hold_required:     r.hold_required,
            watchlist:         r.watchlist,
            overdue_bucket:    r["overdue_bucket_cached"],
            utilization_pct:   r["utilization_pct"].to_f,
          }
        end
    end

    private

    def credit_accounts_base
      scope = CreditAccount.joins(:customer)
                           .where(customers: { organization_id: org_id })
      scope = scope.where(credit_accounts: { branch_id: branch_id }) if branch_id.present?
      scope
    end

    def risky_condition
      "credit_accounts.overdue_amount > 0 OR credit_accounts.hold_required = true OR credit_accounts.watchlist = true OR credit_accounts.available_credit <= 0"
    end
  end
end
