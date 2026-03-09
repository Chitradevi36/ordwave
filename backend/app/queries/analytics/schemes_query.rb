# frozen_string_literal: true

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
          OpenStruct.new(
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
      total_discount  = redemption_scope.sum(:discount_amount).to_d
      total_revenue   = revenue_from_redemptions

      roi_values = active_schemes.where.not(budget_amount: [nil, 0])
                                 .map { |s| roi_pct(s) }.compact
      avg_roi = roi_values.empty? ? nil : (roi_values.sum / roi_values.size).round(1)

      {
        total_schemes:      scheme_scope.count,
        active_schemes:     active_schemes.count,
        total_redemptions:  redemption_scope.count,
        total_discount:     total_discount.round(2),
        total_revenue:      total_revenue.round(2),
        avg_roi_pct:        avg_roi
      }
    end

    def schemes
      scheme_scope
        .left_joins(:redemptions)
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
          "COUNT(scheme_redemptions.id) AS redemption_count",
          "COALESCE(SUM(scheme_redemptions.discount_amount), 0) AS total_discount_sum",
          "COALESCE(SUM(scheme_redemptions.revenue_amount), 0) AS total_revenue_sum"
        )
        .order(Arel.sql("COUNT(scheme_redemptions.id) DESC"))
        .map do |s|
          budget     = s.budget_amount.to_d
          utilized   = s.utilized_amount.to_d
          disc       = s.total_discount_sum.to_d
          rev        = s.total_revenue_sum.to_d
          roi        = disc.zero? ? nil : ((rev - disc) / disc * 100).round(1)
          alert_pct  = s.budget_alert_pct || 80

          {
            scheme_id:        s.id,
            scheme_code:      s.code,
            scheme_name:      s.name,
            scheme_type:      s.scheme_type,
            redemption_count: s.redemption_count.to_i,
            total_discount:   disc.round(2),
            total_revenue:    rev.round(2),
            roi_pct:          roi,
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

    def redemption_scope
      scope = SchemeRedemption.joins(:scheme)
                              .where(schemes: { organization_id: @organization.id })
                              .where(scheme_redemptions: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
      scope = scope.where(schemes: { branch_id: @branch_id }) if @branch_id.present?
      scope
    end

    def revenue_from_redemptions
      redemption_scope.sum(:revenue_amount).to_d
    rescue ActiveRecord::StatementInvalid
      # revenue_amount column may not exist on older schemas
      0.0
    end

    def roi_pct(scheme)
      disc = scheme.utilized_amount.to_d
      return nil if disc.zero?

      rev = scheme.respond_to?(:revenue_amount) ? scheme.revenue_amount.to_d : 0.0
      ((rev - disc) / disc * 100).round(1)
    end
  end
end

  #
  # Usage:
  #   query = Analytics::SchemesQuery.new(
  #     organization: org,
  #     branch_id:    nil,
  #     date_from:    '2025-01-01',
  #     date_to:      '2025-03-31'
  #   )
  #   query.summary        # => { total_schemes:, active:, budget_utilization:, ... }
  #   query.top_schemes    # => [{ id:, name:, redemptions:, discount_given:, budget_pct: }, ...]
  #   query.by_channel     # => [{ channel:, redemptions:, discount_given: }, ...]
  class SchemesQuery
    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil)
      @organization = organization
      @branch_id    = branch_id
      @date_from    = date_from&.to_date || 30.days.ago.to_date
      @date_to      = date_to&.to_date   || Date.current
    end

    def summary
      active_schemes   = scheme_scope.where(status: 'active')
      expired_schemes  = scheme_scope.where(status: 'expired')
      draft_schemes    = scheme_scope.where(status: 'draft')
      total_budget     = active_schemes.sum(:budget_amount).to_d
      total_utilised   = active_schemes.sum(:utilized_amount).to_d

      {
        total_schemes:      scheme_scope.count,
        active:             active_schemes.count,
        draft:              draft_schemes.count,
        expired:            expired_schemes.count,
        total_budget:       total_budget.round(2),
        total_utilized:     total_utilised.round(2),
        budget_utilization: budget_pct(total_budget, total_utilised),
        total_redemptions:  redemption_scope.count,
        total_discount:     redemption_scope.sum(:discount_amount).to_d.round(2)
      }
    end

    def top_schemes(limit: 10)
      redemption_scope
        .joins(:scheme)
        .group('schemes.id, schemes.name, schemes.budget_amount, schemes.utilized_amount')
        .order(Arel.sql('COUNT(*) DESC'))
        .limit(limit)
        .select('schemes.id, schemes.name, schemes.budget_amount, schemes.utilized_amount, COUNT(*) AS redemptions, SUM(scheme_redemptions.discount_amount) AS discount_given')
        .map do |row|
          {
            id:            row.id,
            name:          row.name,
            redemptions:   row.redemptions.to_i,
            discount_given: row.discount_given.to_d.round(2),
            budget_pct:    budget_pct(row.budget_amount.to_d, row.utilized_amount.to_d)
          }
        end
    end

    def by_channel
      redemption_scope
        .joins(:scheme)
        .group('schemes.channel')
        .select('schemes.channel, COUNT(*) AS redemptions, SUM(scheme_redemptions.discount_amount) AS discount_given')
        .map do |row|
          { channel: row.channel, redemptions: row.redemptions.to_i, discount_given: row.discount_given.to_d.round(2) }
        end
    end

    def timeseries(grouping: 'day')
      format = case grouping
               when 'week'  then 'IYYY-IW'
               when 'month' then 'YYYY-MM'
               else              'YYYY-MM-DD'
               end

      redemption_scope
        .group("TO_CHAR(scheme_redemptions.created_at, '#{format}')")
        .order(Arel.sql("TO_CHAR(scheme_redemptions.created_at, '#{format}')"))
        .select("TO_CHAR(scheme_redemptions.created_at, '#{format}') AS period, COUNT(*) AS count, SUM(discount_amount) AS discount_given")
        .map { |r| { period: r.period, count: r.count.to_i, discount_given: r.discount_given.to_d.round(2) } }
    end

    private

    def scheme_scope
      scope = Scheme.where(organization: @organization)
      scope = scope.where(branch_id: @branch_id) if @branch_id.present?
      scope
    end

    def redemption_scope
      scope = SchemeRedemption.joins(:scheme)
                              .where(schemes: { organization_id: @organization.id })
                              .where(scheme_redemptions: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
      scope = scope.where(schemes: { branch_id: @branch_id }) if @branch_id.present?
      scope
    end

    def budget_pct(budget, utilized)
      return 0.0 if budget.zero?

      (utilized / budget * 100).round(1)
    end
  end
end
