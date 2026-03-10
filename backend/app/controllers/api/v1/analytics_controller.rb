# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      before_action :require_organization!
      before_action :authorize_analytics!

      # Skip the Pundit after_action hooks — we handle authorization manually
      # via authorize_analytics! and authorize_export! above.
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      # GET /api/v1/analytics/overview
      # Lightweight summary of all 5 dashboards for the main insights page.
      def overview
        data = cached("overview") do
          {
            sales:       sales_query.orders_summary.merge(sales_query.invoices_summary),
            collections: collections_query.summary,
            credit_risk: credit_risk_query.summary,
            beat:        beat_query.summary,
            inventory:   inventory_query.summary,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/sales
      def sales
        grouping = params.fetch(:grouping, "day")
        data = cached("sales/#{grouping}") do
          {
            orders:      sales_query.orders_summary,
            invoices:    sales_query.invoices_summary,
            timeseries:  sales_query.timeseries(grouping: grouping),
            top_retailers: sales_query.top_retailers,
            top_products:  sales_query.top_products,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/collections
      def collections
        grouping = params.fetch(:grouping, "day")
        data = cached("collections/#{grouping}") do
          {
            summary:         collections_query.summary,
            timeseries:      collections_query.timeseries(grouping: grouping),
            target_vs_actual: collections_query.target_vs_actual,
            by_mode:         collections_query.by_mode,
            overdue_by_age:  collections_query.overdue_by_age,
            top_collectors:  collections_query.top_collectors,
          }
        end

        # Paginated unpaid invoices list (not cached — live data)
        unpaid = paginate(collections_query.unpaid_invoices_relation)

        render_success(
          data.merge(unpaid_invoices: unpaid.map { |i| serialize_invoice(i) }),
          meta: pagination_meta(unpaid)
        )
      end

      # GET /api/v1/analytics/credit_risk
      def credit_risk
        data = cached("credit_risk") do
          {
            summary:         credit_risk_query.summary,
            aging_buckets:   credit_risk_query.aging_buckets,
            risky_retailers: credit_risk_query.risky_retailers,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/beat_performance
      def beat_performance
        data = cached("beat/#{effective_sales_rep_id}") do
          {
            summary:    beat_query.summary,
            reps_table: beat_query.reps_table,
            beats_table: beat_query.beats_table,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/inventory_health
      def inventory_health
        data = cached("inventory") do
          {
            summary:      inventory_query.summary,
            low_stock:    inventory_query.low_stock,
            dead_stock:   inventory_query.dead_stock,
            fast_moving:  inventory_query.fast_moving,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/returns
      def returns
        data = cached("returns") do
          {
            summary:     returns_query.summary,
            by_reason:   returns_query.by_reason,
            by_month:    returns_query.by_month,
            by_product:  returns_query.by_product,
            by_customer: returns_query.by_customer,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/schemes
      def schemes
        data = cached("schemes") do
          {
            summary: schemes_query.summary,
            schemes: schemes_query.schemes,
          }
        end
        render_success(data)
      end

      # GET /api/v1/analytics/collections/export
      def collections_csv
        authorize_export!

        require "csv"

        invoices = collections_query.unpaid_invoices_relation.limit(5000)

        csv_string = CSV.generate(headers: true) do |csv|
          csv << %w[invoice_number customer_name invoice_date due_date
                    grand_total outstanding_amount paid_amount]

          invoices.each do |inv|
            csv << [
              inv.invoice_number,
              inv["customer_name"],
              inv.invoice_date,
              inv.due_date,
              inv.grand_total,
              inv.outstanding_amount,
              inv.paid_amount,
            ]
          end
        end

        send_data csv_string,
                  type:        "text/csv; charset=utf-8",
                  disposition: "attachment",
                  filename:    "unpaid_invoices_#{Date.current}.csv"
      end

      private

      # ── Authorization ─────────────────────────────────────────────────────

      def analytics_policy
        @analytics_policy ||= AnalyticsPolicy.new(pundit_user, :analytics)
      end

      def authorize_analytics!
        raise Pundit::NotAuthorizedError unless analytics_policy.read?
      end

      def authorize_export!
        raise Pundit::NotAuthorizedError unless analytics_policy.export?
      end

      # ── Shared query params ───────────────────────────────────────────────

      def filter_branch_id
        params[:branch_id].presence
      end

      def filter_date_from
        params[:date_from].presence || params[:from].presence
      end

      def filter_date_to
        params[:date_to].presence || params[:to].presence
      end

      # If the current user is a sales_rep, lock to their own data.
      def effective_sales_rep_id
        if current_role&.name == "sales_rep"
          current_user.id
        else
          params[:sales_rep_id].presence
        end
      end

      # ── Query objects ─────────────────────────────────────────────────────

      def sales_query
        @sales_query ||= ::Analytics::SalesSummaryQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          date_from:    filter_date_from,
          date_to:      filter_date_to
        )
      end

      def collections_query
        @collections_query ||= ::Analytics::CollectionsSummaryQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          date_from:    filter_date_from,
          date_to:      filter_date_to
        )
      end

      def credit_risk_query
        @credit_risk_query ||= ::Analytics::CreditRiskQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          sales_rep_id: effective_sales_rep_id
        )
      end

      def beat_query
        @beat_query ||= ::Analytics::BeatPerformanceQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          date_from:    filter_date_from,
          date_to:      filter_date_to,
          sales_rep_id: effective_sales_rep_id
        )
      end

      def inventory_query
        @inventory_query ||= ::Analytics::InventoryHealthQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id
        )
      end

      def returns_query
        @returns_query ||= ::Analytics::ReturnsQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          date_from:    filter_date_from,
          date_to:      filter_date_to
        )
      end

      def schemes_query
        @schemes_query ||= ::Analytics::SchemesQuery.new(
          organization: current_organization,
          branch_id:    filter_branch_id,
          date_from:    filter_date_from,
          date_to:      filter_date_to
        )
      end

      # ── Caching ───────────────────────────────────────────────────────────

      # Cache key includes org, branch, date range and the segment name.
      # TTL: 5 minutes.
      def cached(segment, &block)
        key = [
          "analytics",
          current_organization.id,
          filter_branch_id || "all",
          filter_date_from || "default_from",
          filter_date_to   || "default_to",
          segment,
        ].join("/")

        Rails.cache.fetch(key, expires_in: 5.minutes, &block)
      end

      # ── Serializers ───────────────────────────────────────────────────────

      def serialize_invoice(inv)
        {
          id:                 inv.id,
          invoice_number:     inv.invoice_number,
          customer_name:      inv["customer_name"],
          invoice_date:       inv.invoice_date,
          due_date:           inv.due_date,
          grand_total:        inv.grand_total.to_d,
          outstanding_amount: inv.outstanding_amount.to_d,
          paid_amount:        inv.paid_amount.to_d,
        }
      end
    end
  end
end
