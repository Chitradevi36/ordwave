# frozen_string_literal: true

require "ostruct"

module Analytics
  # Aggregates scheme (trade promotion) performance data using SchemeApplication records.
  #
  # Returns shape expected by web/app/insights/schemes/page.tsx:
  #   summary: { total_schemes, active_schemes, total_redemptions, total_discount, total_revenue, avg_roi_pct }
  #   schemes: [{ scheme_id, scheme_code, scheme_name, scheme_type, redemption_count,
  #               total_discount, total_revenue, roi_pct, budget_amount, budget_utilized, budget_alert_pct }]
  class SchemesQuery
    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil)
      @organization = organization
      @branch_id    = branch_id
      @date_from    = date_from&.to_date || 30.days.ago.to_date
      @date_to      = date_to&.to_date   || Date.current
    end

    def summary
      active_schemes  = scheme_scope.where(status: 'active')
      apps           = application_scope
      total_discount = apps
        .sum(Arel.sql("(breakdown->>'discount_total')::decimal"))
        .to_d

      {
        total_schemes:      scheme_scope.count,
        active_schemes:     active_schemes.count,
        total_redemptions:  apps.count,
        total_discount:     total_discount.round(2),
        total_revenue:      0.0,   # revenue attribution requires order-level join; not available here
        avg_roi_pct:        nil
      }
    end

    def schemes
      # Per-scheme aggregates joined from scheme_applications
      rows = application_scope
        .joins(:scheme)
        .group("schemes.id, schemes.name, schemes.code, schemes.scheme_type, " \
               "schemes.budget_amount, schemes.utilized_amount, schemes.budget_alert_pct")
        .select(
          "schemes.id",
          "schemes.name",
          "schemes.code",
          "schemes.scheme_type",
          "schemes.budget_amount",
          "schemes.utilized_amount",
          "schemes.budget_alert_pct",
          "COUNT(scheme_applications.id) AS redemption_count",
          "COALESCE(SUM((scheme_applications.breakdown->>'discount_total')::decimal), 0) AS total_discount_sum"
        )
        .order(Arel.sql("COUNT(scheme_applications.id) DESC"))

      # Also include active schemes with zero applications in the period
      app_scheme_ids = rows.map(&:id).to_set

      # Schemes with no applications in period
      zero_rows = scheme_scope
        .where.not(id: app_scheme_ids)
        .select(:id, :name, :code, :scheme_type, :budget_amount, :utilized_amount, :budget_alert_pct)
        .map do |s|
          ::OpenStruct.new(
            id: s.id, name: s.name, code: s.code, scheme_type: s.scheme_type,
            budget_amount: s.budget_amount, utilized_amount: s.utilized_amount,
            budget_alert_pct: s.budget_alert_pct,
            redemption_count: 0, total_discount_sum: 0
          )
        end

      (rows.to_a + zero_rows).map do |s|
        budget    = s.budget_amount.to_d
        utilized  = s.utilized_amount.to_d
        disc      = s.total_discount_sum.to_d
        alert_pct = s.budget_alert_pct || 80

        {
          scheme_id:        s.id,
          scheme_code:      s.code,
          scheme_name:      s.name,
          scheme_type:      s.scheme_type,
          redemption_count: s.redemption_count.to_i,
          total_discount:   disc.round(2),
          total_revenue:    0.0,
          roi_pct:          nil,
          budget_amount:    budget.positive? ? budget.round(2) : nil,
          budget_utilized:  utilized.round(2),
          budget_alert_pct: alert_pct
        }
      end
    end

    private

    def scheme_scope
      scope = Scheme.where(organization: @organization)
      scope = scope.where(branch_id: @branch_id) if @branch_id.present?
      scope
    end

    def application_scope
      scope = SchemeApplication
        .joins(:scheme)
        .where(schemes: { organization_id: @organization.id })
        .where(source: 'submit_snapshot')
        .where(applied_at: @date_from.beginning_of_day..@date_to.end_of_day)
      scope = scope.where(schemes: { branch_id: @branch_id }) if @branch_id.present?
      scope
    end
  end
end
