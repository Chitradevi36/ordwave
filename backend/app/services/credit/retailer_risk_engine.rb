# frozen_string_literal: true
#
# Credit::RetailerRiskEngine
# ─────────────────────────────────────────────────────────────────────────────
# Computes a 0–100 risk score for a retailer using weighted business-rule
# signals.  Results are explained factor-by-factor so every score is fully
# auditable.
#
# SCORING MODEL VERSION: v1
#
# Architecture notes
# ──────────────────
# • Pure functional — no side-effects; call .compute to get a result hash.
# • All signal weights and thresholds are constants; swap them without touching
#   logic (or sub-class for ML scoring in v2).
# • Persists a RetailerRiskSnapshot via .compute_and_save!
#
# Scoring factors (total budget = 100 points = maximum possible risk)
# ───────────────────────────────────────────────────────────────────
#   Signal                          Max pts
#   ─────────────────────────────── ───────
#   Overdue severity                  30
#   Credit utilization pressure       25
#   Payment reversals (6-month)       18
#   Payment delay trend (avg days)    15
#   Manual watchlist flag             6
#   Order frequency trend             6
#   Credit limit change requests      5
#   Bonus: stable / early payment    −5  (negative, reduces score)
#                                   ────
#   Max raw                          105  → clamped to 100
#
module Credit
  class RetailerRiskEngine
    SCORE_VERSION = 'v1'.freeze

    # ── Tier cut-offs ────────────────────────────────────────────────────────
    TIER_THRESHOLDS = {
      'critical' => 75,
      'high'     => 50,
      'medium'   => 25,
      'low'      => 0,
    }.freeze

    # ── Recommendations by tier ──────────────────────────────────────────────
    TIER_RECOMMENDATIONS = {
      'low'      => 'Allow order — retailer is in good standing.',
      'medium'   => 'Allow order with warning — review outstanding balance.',
      'high'     => 'Hold order — manager approval required before dispatch.',
      'critical' => 'Block order — require full collection before new order.',
    }.freeze

    # ── Entry points ─────────────────────────────────────────────────────────

    # Returns a result hash without persisting.
    def self.compute(customer)
      new(customer).compute
    end

    # Computes and persists a RetailerRiskSnapshot. Returns the snapshot record.
    def self.compute_and_save!(customer)
      result   = compute(customer)
      snapshot = RetailerRiskSnapshot.where(customer: customer, organization: customer.organization)
                                     .order(computed_at: :desc)
                                     .first_or_initialize

      snapshot.assign_attributes(
        organization:  customer.organization,
        risk_score:    result[:score],
        risk_tier:     result[:tier],
        recommendation: result[:recommendation],
        factors_json:  { factors: result[:factors] },
        score_version: SCORE_VERSION,
        computed_at:   Time.current,
      )
      snapshot.save!
      snapshot
    end

    # ── Initialiser ──────────────────────────────────────────────────────────

    def initialize(customer)
      @customer    = customer
      @account     = customer.credit_account
      @factors     = []
      @total_score = 0
    end

    # ── Main computation ─────────────────────────────────────────────────────

    def compute
      return neutral_result('No credit account found') unless @account

      score_overdue_severity
      score_credit_utilization
      score_payment_reversals
      score_payment_delay_trend
      score_watchlist
      score_order_frequency_trend
      score_credit_limit_requests
      score_payment_bonus

      final_score = @total_score.clamp(0, 100)
      tier        = tier_for(final_score)

      {
        score:          final_score,
        tier:           tier,
        recommendation: TIER_RECOMMENDATIONS[tier],
        factors:        @factors,
        computed_at:    Time.current.iso8601,
        score_version:  SCORE_VERSION,
      }
    end

    private

    # ── Signal 1: Overdue severity (0–30 pts) ─────────────────────────────

    def score_overdue_severity
      days  = @account.overdue_days.to_i
      pts   = case days
              when 0     then 0
              when 1..7  then 5
              when 8..14 then 10
              when 15..29 then 20
              when 30..59 then 27
              else 30
              end
      add_factor(
        key:    'overdue_days',
        label:  "Overdue #{days} day#{days == 1 ? '' : 's'}",
        points: pts,
        detail: "Retailer is #{days} days overdue on payments."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 2: Credit utilization (0–25 pts) ────────────────────────────

    def score_credit_utilization
      limit   = @account.credit_limit.to_f
      return unless limit > 0

      balance = @account.current_balance.to_f
      pct     = ((balance / limit) * 100).round(1)
      pts     = case pct
                when 0..40   then 0
                when 41..60  then 5
                when 61..75  then 10
                when 76..90  then 18
                when 91..100 then 22
                else 25   # above 100%
                end
      add_factor(
        key:    'credit_utilization',
        label:  "#{pct}% credit utilization",
        points: pts,
        detail: "Balance ₹#{fmt(balance)} against limit ₹#{fmt(limit)}."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 3: Payment reversals – last 6 months (0–18 pts) ────────────

    def score_payment_reversals
      reversals = Payment.where(
        customer: @customer,
        organization: @customer.organization,
        status: 'reversed'
      ).where('received_date >= ?', 6.months.ago).count

      pts = case reversals
            when 0   then 0
            when 1   then 8
            when 2   then 13
            else 18
            end
      add_factor(
        key:    'payment_reversals',
        label:  "#{reversals} payment reversal#{reversals == 1 ? '' : 's'} (6 months)",
        points: pts,
        detail: "#{reversals} payment#{reversals == 1 ? '' : 's'} reversed in the last 6 months."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 4: Payment delay trend (0–15 pts) ───────────────────────────
    # Average days between invoice_date and payment received_date over last 90 days.
    # Compared against customer.credit_days.

    def score_payment_delay_trend
      recent_payments = Payment
        .joins(:allocations => :sales_invoice)
        .where(customer: @customer, organization: @customer.organization, status: 'confirmed')
        .where('payments.received_date >= ?', 90.days.ago)
        .pluck('payments.received_date', 'sales_invoices.issued_at')
        .reject { |paid, issued| issued.nil? }

      return unless recent_payments.any?

      avg_delay = recent_payments.sum { |paid, issued|
        (paid.to_date - issued.to_date).to_i
      }.to_f / recent_payments.length

      credit_days = @customer.credit_days.to_i
      delay_vs_terms = avg_delay - credit_days  # positive = late

      pts = case delay_vs_terms
            when -Float::INFINITY..-1 then 0   # early payer — bonus handled separately
            when 0..7                 then 0
            when 8..15                then 5
            when 16..30               then 10
            else 15
            end

      @avg_payment_delay = delay_vs_terms  # stash for bonus signal

      add_factor(
        key:    'payment_delay_trend',
        label:  "Avg payment #{delay_vs_terms.round(1)} days vs credit terms",
        points: pts,
        detail: "Average payment received #{avg_delay.round(1)} days after invoice; credit terms: #{credit_days} days."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 5: Manual watchlist flag (0–6 pts) ─────────────────────────

    def score_watchlist
      return unless @account.watchlist?

      pts = 6
      add_factor(
        key:    'watchlist',
        label:  'Flagged on manual watchlist',
        points: pts,
        detail: 'Distributor has manually flagged this retailer for heightened monitoring.'
      )
      @total_score += pts
    end

    # ── Signal 6: Order frequency trend (0–6 pts) ─────────────────────────

    def score_order_frequency_trend
      last_30  = SalesOrder.where(customer: @customer, organization: @customer.organization)
                           .where('created_at >= ?', 30.days.ago).count
      last_60  = SalesOrder.where(customer: @customer, organization: @customer.organization)
                           .where('created_at >= ?', 60.days.ago)
                           .where('created_at < ?',  30.days.ago).count

      pts = if last_30 == 0 && last_60 == 0
              6  # inactive customer — higher risk
            elsif last_30 == 0
              4  # ordered last month but not this month
            elsif last_30 < last_60 * 0.5
              2  # significant drop
            else
              0
            end
      add_factor(
        key:    'order_frequency',
        label:  "Order frequency: #{last_30} (30d) vs #{last_60} (prior 30d)",
        points: pts,
        detail: "Orders placed in last 30 days: #{last_30}. Prior 30 days: #{last_60}."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 7: Recent credit limit change requests (0–5 pts) ──────────

    def score_credit_limit_requests
      requests = CreditLimitChangeRequest
        .joins(:credit_account)
        .where(credit_accounts: { customer_id: @customer.id })
        .where('credit_limit_change_requests.created_at >= ?', 90.days.ago)
        .count

      pts = case requests
            when 0 then 0
            when 1 then 2
            else 5
            end
      add_factor(
        key:    'limit_change_requests',
        label:  "#{requests} credit limit request#{requests == 1 ? '' : 's'} (90 days)",
        points: pts,
        detail: "#{requests} request#{requests == 1 ? '' : 's'} to increase credit limit in the last 90 days."
      ) if pts > 0
      @total_score += pts
    end

    # ── Signal 8: Bonus — early/prompt payer (−5 pts) ─────────────────────

    def score_payment_bonus
      return unless defined?(@avg_payment_delay) && @avg_payment_delay.present?
      return unless @avg_payment_delay < 0  # pays before due date

      pts = -5
      add_factor(
        key:    'early_payer_bonus',
        label:  "Consistently pays before due date (#{@avg_payment_delay.abs.round(1)} days early on avg)",
        points: pts,
        detail: 'Early payment pattern reduces risk score.'
      )
      @total_score += pts
    end

    # ── Helpers ──────────────────────────────────────────────────────────────

    def add_factor(key:, label:, points:, detail:)
      @factors << { key: key, label: label, points: points, detail: detail }
    end

    def tier_for(score)
      TIER_THRESHOLDS.each { |tier, threshold| return tier if score >= threshold }
      'low'
    end

    def fmt(n)
      "#{n.to_i.to_s.reverse.scan(/.{1,3}/).join(',').reverse}"
    end

    def neutral_result(reason)
      {
        score:          0,
        tier:           'low',
        recommendation: 'Insufficient data to assess risk.',
        factors:        [{ key: 'no_data', label: reason, points: 0, detail: reason }],
        computed_at:    Time.current.iso8601,
        score_version:  SCORE_VERSION,
      }
    end
  end
end
