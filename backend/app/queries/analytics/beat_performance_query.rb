# frozen_string_literal: true

module Analytics
  class BeatPerformanceQuery < BaseQuery
    attr_reader :date_from, :date_to, :sales_rep_id

    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil, sales_rep_id: nil)
      super(organization: organization, branch_id: branch_id)
      @date_from    = parse_date(date_from, MTD_BEGIN.call)
      @date_to      = parse_date(date_to,   TODAY.call)
      @sales_rep_id = sales_rep_id.presence&.to_i
    end

    # Overall visit funnel counters
    def summary
      base = visits_base

      planned   = base.where(visit_status: "planned").count
      completed = base.where(visit_status: "completed").count
      skipped   = base.where(visit_status: "skipped").count

      order_conv  = order_conversions(base.where(visit_status: "completed"))
      payment_conv = collection_conversions(base.where(visit_status: "completed"))

      {
        visits_planned:              planned,
        visits_completed:            completed,
        visits_skipped:              skipped,
        completion_rate:             pct(completed, planned + completed + skipped),
        order_conversion_rate:       pct(order_conv, completed),
        collection_conversion_rate:  pct(payment_conv, completed),
        orders_from_visits:          order_conv,
        collections_from_visits:     payment_conv,
      }
    end

    # Per-rep breakdown
    def reps_table
      VisitLog
        .where(organization_id: org_id)
        .where(visit_date: date_from..date_to)
        .then { |s| sales_rep_id.present? ? s.where(sales_rep_id: sales_rep_id) : s }
        .then { |s| branch_id.present? ? s.where(branch_id: branch_id) : s }
        .joins("INNER JOIN users ON users.id = visit_logs.sales_rep_id")
        .group("users.id, users.first_name, users.last_name")
        .select(
          "users.id AS rep_id",
          "users.first_name",
          "users.last_name",
          "COUNT(*) FILTER (WHERE visit_logs.visit_status = 'completed') AS completed",
          "COUNT(*) FILTER (WHERE visit_logs.visit_status = 'planned')   AS planned",
          "COUNT(*) FILTER (WHERE visit_logs.visit_status = 'skipped')   AS skipped",
          "COUNT(*) AS total_visits"
        )
        .order(Arel.sql("COUNT(*) FILTER (WHERE visit_logs.visit_status = 'completed') DESC"))
        .map do |r|
          {
            rep_id:    r["rep_id"],
            name:      "#{r["first_name"]} #{r["last_name"]}".strip,
            completed: r["completed"].to_i,
            planned:   r["planned"].to_i,
            skipped:   r["skipped"].to_i,
            total:     r["total_visits"].to_i,
            completion_rate: pct(r["completed"].to_i, r["total_visits"].to_i),
          }
        end
    end

    # Completion rate per beat-schedule
    def beats_table
      VisitLog
        .where(organization_id: org_id)
        .where(visit_date: date_from..date_to)
        .where.not(beat_schedule_id: nil)
        .then { |s| sales_rep_id.present? ? s.where(sales_rep_id: sales_rep_id) : s }
        .then { |s| branch_id.present? ? s.where(branch_id: branch_id) : s }
        .joins("INNER JOIN beat_schedules ON beat_schedules.id = visit_logs.beat_schedule_id")
        .joins("INNER JOIN beats ON beats.id = beat_schedules.beat_id")
        .group("beats.id, beats.name")
        .select(
          "beats.id AS beat_id",
          "beats.name AS beat_name",
          "COUNT(*) AS total_visits",
          "COUNT(*) FILTER (WHERE visit_logs.visit_status = 'completed') AS completed",
          "COUNT(*) FILTER (WHERE visit_logs.visit_status = 'skipped')   AS skipped"
        )
        .order(Arel.sql("beats.name"))
        .map do |r|
          {
            beat_id:         r["beat_id"],
            beat_name:       r["beat_name"],
            completed:       r["completed"].to_i,
            skipped:         r["skipped"].to_i,
            total:           r["total_visits"].to_i,
            completion_rate: pct(r["completed"].to_i, r["total_visits"].to_i),
          }
        end
    end

    private

    def visits_base
      scope = VisitLog
                .where(organization_id: org_id)
                .where(visit_date: date_from..date_to)
      scope = scope.where(branch_id: branch_id)      if branch_id.present?
      scope = scope.where(sales_rep_id: sales_rep_id) if sales_rep_id.present?
      scope
    end

    # Count completed visits that produced a sales order same day (by same rep)
    def order_conversions(completed_scope)
      completed_scope
        .where(
          "EXISTS (
            SELECT 1 FROM sales_orders so
            WHERE so.customer_id   = visit_logs.customer_id
              AND so.created_by_id = visit_logs.sales_rep_id
              AND DATE(so.created_at) = visit_logs.visit_date
              AND so.organization_id  = visit_logs.organization_id
          )"
        ).count
    end

    # Count completed visits that produced a confirmed payment same day (by same rep)
    def collection_conversions(completed_scope)
      completed_scope
        .where(
          "EXISTS (
            SELECT 1 FROM payments p
            WHERE p.customer_id    = visit_logs.customer_id
              AND p.created_by_id  = visit_logs.sales_rep_id
              AND p.received_date  = visit_logs.visit_date
              AND p.status         = 'confirmed'
              AND p.organization_id = visit_logs.organization_id
          )"
        ).count
    end
  end
end
