# frozen_string_literal: true

module Analytics
  # Scheme performance analytics — ROI, budget utilization, top schemes.
  #
  # Usage:
  #   result = Analytics::SchemePerformanceReport.call(
  #     organization: org,
  #     from:         30.days.ago,
  #     to:           Date.current
  #   )
  #   result.budget_summary       # => [{ scheme_id:, name:, budget:, utilized:, pct:, ... }, ...]
  #   result.top_schemes_by_usage # => [{ scheme_id:, name:, redemption_count:, total_discount: }, ...]
  #   result.roi_summary          # => [{ scheme_id:, name:, cost:, revenue:, roi_pct: }, ...]
  #   result.overall              # => { total_budget:, total_utilized:, schemes_count:, ... }
  #
  class SchemePerformanceReport
    Result = Struct.new(:success?, :budget_summary, :top_schemes_by_usage, :roi_summary, :overall, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, from: 30.days.ago, to: Time.current, branch: nil)
      @organization = organization
      @from         = from
      @to           = to
      @branch       = branch
    end

    def call
      schemes = schemes_scope

      Result.new(
        true,
        compute_budget_summary(schemes),
        compute_top_schemes(schemes),
        compute_roi(schemes),
        compute_overall(schemes),
        []
      )
    rescue StandardError => e
      Result.new(false, [], [], [], {}, [e.message])
    end

    private

    def schemes_scope
      scope = Scheme.where(organization_id: @organization.id)
      scope = scope.where(branch_id: @branch.id) if @branch
      scope
    end

    # Budget utilization for schemes that have a budget set
    def compute_budget_summary(schemes)
      schemes
        .where.not(budget_amount: nil)
        .select(:id, :name, :scheme_type, :status, :budget_amount, :utilized_amount, :budget_alert_pct)
        .order("utilized_amount DESC")
        .map do |s|
          pct = s.budget_amount.to_d.positive? ? (s.utilized_amount.to_d / s.budget_amount.to_d * 100).round(1) : 0
          {
            scheme_id:        s.id,
            name:             s.name,
            scheme_type:      s.scheme_type,
            status:           s.status,
            budget_amount:    s.budget_amount.to_d.round(2),
            utilized_amount:  s.utilized_amount.to_d.round(2),
            remaining:        (s.budget_amount.to_d - s.utilized_amount.to_d).round(2),
            utilization_pct:  pct,
            alert_triggered:  pct >= s.budget_alert_pct.to_i
          }
        end
    end

    # Top schemes by number of redemptions (via scheme_applications or order_scheme_discounts)
    def compute_top_schemes(schemes)
      # Uses sales_order_lines that reference scheme discounts within the period
      SalesOrderLine
        .joins(:sales_order)
        .where(sales_orders: { organization_id: @organization.id, created_at: @from..@to })
        .where.not(applied_scheme_id: nil)
        .where(applied_scheme_id: schemes.select(:id))
        .group(:applied_scheme_id)
        .select(
          "sales_order_lines.applied_scheme_id AS scheme_id",
          "COUNT(*) AS redemption_count",
          "SUM(sales_order_lines.discount_amount) AS total_discount"
        )
        .order("redemption_count DESC")
        .limit(20)
        .map do |row|
          scheme = schemes.find { |s| s.id == row.scheme_id }
          {
            scheme_id:        row.scheme_id,
            name:             scheme&.name || 'Unknown',
            redemption_count: row.redemption_count.to_i,
            total_discount:   row.total_discount.to_d.round(2)
          }
        end
    rescue StandardError
      # If sales_order_lines doesn't have applied_scheme_id, fall back to scheme utilized_amount
      schemes
        .where("utilized_amount > 0")
        .order("utilized_amount DESC")
        .limit(20)
        .map do |s|
          {
            scheme_id:        s.id,
            name:             s.name,
            redemption_count: nil, # not available without line-level tracking
            total_discount:   s.utilized_amount.to_d.round(2)
          }
        end
    end

    # ROI: cost (discount given) vs revenue (order value where scheme was applied)
    def compute_roi(schemes)
      rows = SalesOrderLine
               .joins(:sales_order)
               .where(sales_orders: { organization_id: @organization.id, created_at: @from..@to })
               .where.not(applied_scheme_id: nil)
               .where(applied_scheme_id: schemes.select(:id))
               .group(:applied_scheme_id)
               .select(
                 "sales_order_lines.applied_scheme_id AS scheme_id",
                 "SUM(sales_order_lines.discount_amount) AS total_cost",
                 "SUM(sales_order_lines.line_total) AS total_revenue"
               )

      rows.map do |row|
        scheme  = schemes.find { |s| s.id == row.scheme_id }
        cost    = row.total_cost.to_d
        revenue = row.total_revenue.to_d
        roi_pct = cost.positive? ? ((revenue - cost) / cost * 100).round(1) : 0

        {
          scheme_id:    row.scheme_id,
          name:         scheme&.name || 'Unknown',
          cost:         cost.round(2),
          revenue:      revenue.round(2),
          roi_pct:      roi_pct
        }
      end.sort_by { |r| -r[:roi_pct] }
    rescue StandardError
      []
    end

    def compute_overall(schemes)
      active_count     = schemes.where(status: 'active').count
      total_count      = schemes.count
      with_budget      = schemes.where.not(budget_amount: nil)
      total_budget     = with_budget.sum(:budget_amount).to_d.round(2)
      total_utilized   = with_budget.sum(:utilized_amount).to_d.round(2)
      exhausted_count  = with_budget.where("utilized_amount >= budget_amount").count
      alerts_triggered = with_budget
                           .where("utilized_amount::numeric / NULLIF(budget_amount::numeric, 0) * 100 >= budget_alert_pct")
                           .count

      {
        total_schemes:    total_count,
        active_schemes:   active_count,
        total_budget:     total_budget,
        total_utilized:   total_utilized,
        utilization_pct:  total_budget.positive? ? (total_utilized / total_budget * 100).round(1) : 0,
        exhausted_count:  exhausted_count,
        alerts_triggered: alerts_triggered
      }
    end
  end
end
