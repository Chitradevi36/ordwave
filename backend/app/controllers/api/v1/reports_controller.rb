# frozen_string_literal: true

module Api
  module V1
    # Reports Controller — downloadable, filterable business reports.
    #
    # All endpoints return JSON by default. Pass ?format=csv to receive a
    # CSV attachment.  Every report is scoped to the current organisation and
    # respects branch / date-range filters:
    #   branch_id=, date_from=YYYY-MM-DD, date_to=YYYY-MM-DD
    #
    # Routes (nested under /api/v1):
    #   GET /reports/sales_summary
    #   GET /reports/collection_summary
    #   GET /reports/product_performance
    #   GET /reports/customer_outstanding
    #   GET /reports/sales_rep_performance
    #   GET /reports/delivery_performance
    #   GET /reports/ageing_report
    class ReportsController < BaseController
      before_action :require_organization!

      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      CSV_MIME = "text/csv"

      # ── GET /api/v1/reports/sales_summary ─────────────────────────────────
      def sales_summary
        from, to_d = date_range
        rows = SalesOrder
          .joins(:customer)
          .where(organization: current_organization)
          .then { |q| filter_branch(q, :branch_id) }
          .where(created_at: from..to_d)
          .where.not(status: "draft")
          .group("customers.name", "sales_orders.status")
          .select(
            "customers.name AS customer_name",
            "sales_orders.status",
            "COUNT(*) AS order_count",
            "COALESCE(SUM(sales_orders.total_amount),0) AS total_value"
          )

        totals = SalesOrder
          .where(organization: current_organization)
          .then { |q| filter_branch(q, :branch_id) }
          .where(created_at: from..to_d)
          .where.not(status: "draft")
          .pick(
            "COUNT(*)",
            "COALESCE(SUM(total_amount),0)"
          )

        data = {
          period:      { from: from, to: to_d },
          summary:     { total_orders: totals[0], total_value: totals[1] },
          rows:        rows.map { |r| row_to_h(r, %w[customer_name status order_count total_value]) }
        }

        respond_with_report(data, :sales_summary, %w[customer_name status order_count total_value])
      end

      # ── GET /api/v1/reports/collection_summary ────────────────────────────
      def collection_summary
        from, to_d = date_range
        base = Payment.where(organization: current_organization)
                      .where(status: "confirmed")
                      .then { |q| filter_branch(q, :branch_id) }
                      .where(received_date: from..to_d)

        rows = base
          .joins("LEFT JOIN users ON users.id = payments.created_by_id")
          .group("users.first_name", "users.last_name", "payments.payment_mode")
          .select(
            "users.first_name || ' ' || users.last_name AS collector_name",
            "payments.payment_mode",
            "COUNT(*) AS payment_count",
            "COALESCE(SUM(payments.amount),0) AS total_collected"
          )

        total = base.sum(:amount)

        data = {
          period:  { from: from, to: to_d },
          summary: { total_collected: total },
          rows:    rows.map { |r| row_to_h(r, %w[collector_name payment_mode payment_count total_collected]) }
        }

        respond_with_report(data, :collection_summary, %w[collector_name payment_mode payment_count total_collected])
      end

      # ── GET /api/v1/reports/product_performance ───────────────────────────
      def product_performance
        from, to_d = date_range
        category_id = params[:category_id]

        rows = SalesOrderLine
          .joins(:sales_order, :product)
          .where(sales_orders: { organization_id: current_organization.id })
          .then { |q| filter_branch(q, "sales_orders.branch_id") }
          .where(sales_orders: { created_at: from..to_d })
          .where.not(sales_orders: { status: "draft" })
          .then { |q| category_id.present? ? q.where(products: { category_id: category_id }) : q }
          .group("products.id", "products.name", "products.sku")
          .select(
            "products.id AS product_id",
            "products.name AS product_name",
            "products.sku AS sku",
            "COUNT(DISTINCT sales_orders.id) AS order_count",
            "COALESCE(SUM(sales_order_lines.qty),0) AS total_qty",
            "COALESCE(SUM(sales_order_lines.qty * sales_order_lines.unit_price),0) AS total_revenue"
          )
          .order("total_revenue DESC")
          .limit(200)

        data = {
          period: { from: from, to: to_d },
          rows:   rows.map { |r| row_to_h(r, %w[product_id product_name sku order_count total_qty total_revenue]) }
        }

        respond_with_report(data, :product_performance, %w[product_name sku order_count total_qty total_revenue])
      end

      # ── GET /api/v1/reports/customer_outstanding ──────────────────────────
      def customer_outstanding
        rows = Customer
          .where(organization: current_organization)
          .where("outstanding_balance > 0")
          .order("outstanding_balance DESC")
          .select(:id, :name, :phone, :credit_limit, :outstanding_balance, :overdue_amount)

        data = {
          generated_at: Time.current.iso8601,
          rows: rows.map do |c|
            {
              customer_id:         c.id,
              customer_name:       c.name,
              phone:               c.phone,
              credit_limit:        c.credit_limit.to_d,
              outstanding_balance: c.outstanding_balance.to_d,
              overdue_amount:      c.overdue_amount.to_d
            }
          end
        }

        respond_with_report(data, :customer_outstanding, %w[customer_name phone credit_limit outstanding_balance overdue_amount])
      end

      # ── GET /api/v1/reports/sales_rep_performance ─────────────────────────
      def sales_rep_performance
        from, to_d = date_range

        rows = SalesOrder
          .joins("LEFT JOIN users AS reps ON reps.id = sales_orders.created_by_id")
          .where(organization: current_organization)
          .then { |q| filter_branch(q, :branch_id) }
          .where(created_at: from..to_d)
          .where.not(status: "draft")
          .group("reps.id", "reps.first_name", "reps.last_name")
          .select(
            "reps.id AS user_id",
            "reps.first_name || ' ' || reps.last_name AS rep_name",
            "COUNT(*) AS orders_count",
            "COALESCE(SUM(sales_orders.total_amount),0) AS orders_value",
            "COUNT(CASE WHEN sales_orders.status IN ('delivered','partial_delivery') THEN 1 END) AS delivered_count"
          )
          .order("orders_value DESC")

        data = {
          period: { from: from, to: to_d },
          rows:   rows.map { |r| row_to_h(r, %w[user_id rep_name orders_count orders_value delivered_count]) }
        }

        respond_with_report(data, :sales_rep_performance, %w[rep_name orders_count orders_value delivered_count])
      end

      # ── GET /api/v1/reports/delivery_performance ──────────────────────────
      def delivery_performance
        from, to_d = date_range

        trips = DeliveryTrip
          .where(organization: current_organization)
          .where(created_at: from..to_d)

        rows = trips
          .joins("LEFT JOIN users AS drivers ON drivers.id = delivery_trips.driver_id")
          .group("drivers.id", "drivers.first_name", "drivers.last_name", "delivery_trips.status")
          .select(
            "drivers.id AS driver_id",
            "drivers.first_name || ' ' || drivers.last_name AS driver_name",
            "delivery_trips.status",
            "COUNT(*) AS trip_count"
          )

        stop_stats = TripStop
          .joins(:delivery_trip)
          .where(delivery_trips: { organization_id: current_organization.id, created_at: from..to_d })
          .group(:status)
          .count

        data = {
          period:     { from: from, to: to_d },
          stop_stats: stop_stats,
          rows:       rows.map { |r| row_to_h(r, %w[driver_id driver_name status trip_count]) }
        }

        respond_with_report(data, :delivery_performance, %w[driver_name status trip_count])
      end

      # ── GET /api/v1/reports/ageing_report ────────────────────────────────
      def ageing_report
        today = Date.current

        buckets = {
          "0-30 days"   => 0..30,
          "31-60 days"  => 31..60,
          "61-90 days"  => 61..90,
          "91-120 days" => 91..120,
          "120+ days"   => 121..Float::INFINITY
        }

        invoices = SalesInvoice
          .joins(:customer)
          .where(organization: current_organization)
          .then { |q| filter_branch(q, :branch_id) }
          .where("outstanding_amount > 0")
          .where(status: %w[issued partially_paid])
          .select(:id, :invoice_number, :invoice_date, :due_date, :outstanding_amount,
                  :grand_total, "customers.name AS customer_name")

        rows = invoices.map do |inv|
          days_overdue = [today - (inv.due_date || inv.invoice_date), 0].max.to_i
          bucket = buckets.find { |_, range| range.include?(days_overdue) }&.first || "120+ days"
          {
            invoice_number:     inv.invoice_number,
            customer_name:      inv["customer_name"],
            invoice_date:       inv.invoice_date,
            due_date:           inv.due_date,
            outstanding_amount: inv.outstanding_amount.to_d,
            days_overdue:       days_overdue,
            age_bucket:         bucket
          }
        end.sort_by { |r| -r[:days_overdue] }

        # Bucket summary
        summary = buckets.transform_values do |range|
          bucket_rows = rows.select { |r| range.include?(r[:days_overdue]) }
          { count: bucket_rows.size, total: bucket_rows.sum { |r| r[:outstanding_amount] } }
        end

        data = {
          generated_at: today.iso8601,
          summary:      summary,
          rows:         rows
        }

        respond_with_report(data, :ageing_report, %w[invoice_number customer_name invoice_date due_date outstanding_amount days_overdue age_bucket])
      end

      private

      # ── Helpers ────────────────────────────────────────────────────────────

      def date_range
        from = params[:date_from].present? ? Date.parse(params[:date_from]) : 30.days.ago.to_date
        to_d = params[:date_to].present?   ? Date.parse(params[:date_to])   : Date.current
        [from.beginning_of_day, to_d.end_of_day]
      end

      def filter_branch(query, col)
        return query unless params[:branch_id].present?

        query.where(col => params[:branch_id])
      end

      def row_to_h(record, keys)
        keys.each_with_object({}) { |k, h| h[k] = record.try(k) || record[k] }
      end

      def respond_with_report(data, report_name, csv_columns)
        if params[:format] == "csv"
          csv_data = generate_csv(data[:rows] || [], csv_columns)
          send_data csv_data,
                    type:        CSV_MIME,
                    disposition: "attachment",
                    filename:    "#{report_name}_#{Date.current.iso8601}.csv"
        else
          render_success(data)
        end
      end

      def generate_csv(rows, columns)
        require "csv"
        CSV.generate(headers: true) do |csv|
          csv << columns
          rows.each do |row|
            csv << columns.map { |c| row.is_a?(Hash) ? row[c] || row[c.to_sym] : row.send(c) }
          end
        end
      end
    end
  end
end
