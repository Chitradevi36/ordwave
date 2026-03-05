# frozen_string_literal: true

module Analytics
  class SalesSummaryQuery < BaseQuery
    SUBMITTED_ORDER_STATUSES = %w[submitted approved dispatched delivered].freeze

    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil, group_by: "day")
      super(organization: organization, branch_id: branch_id)
      @date_from = parse_date(date_from, MTD_BEGIN.call)
      @date_to   = parse_date(date_to,   TODAY.call)
      @group_by  = group_by.to_s.in?(%w[day week month]) ? group_by.to_s : "day"
    end

    def call
      {
        orders:        orders_summary,
        invoices:      invoices_summary,
        timeseries:    timeseries,
        top_retailers: top_retailers,
        top_products:  top_products,
      }
    end

    def orders_summary
      row = orders_base
              .select("COUNT(*) AS count, COALESCE(SUM(total_amount), 0) AS value")
              .to_a.first
      {
        count: row["count"].to_i,
        value: row["value"].to_d,
        avg:   row["count"].to_i > 0 ? (row["value"].to_d / row["count"].to_i).round(2) : 0,
      }
    end

    def invoices_summary
      row = invoices_base
              .select("COUNT(*) AS count, COALESCE(SUM(grand_total), 0) AS value, COALESCE(SUM(outstanding_amount), 0) AS outstanding")
              .to_a.first
      {
        count:       row["count"].to_i,
        value:       row["value"].to_d,
        outstanding: row["outstanding"].to_d,
      }
    end

    def timeseries(grouping: group_by)
      orders_ts = orders_base
        .group(Arel.sql(trunc_expr("submitted_at", "sales_orders", grouping)))
        .select(Arel.sql("#{trunc_expr("submitted_at", "sales_orders", grouping)} AS period, COUNT(*) AS orders_count, COALESCE(SUM(total_amount), 0) AS orders_value"))
        .map { |r| { period: r["period"].to_s, orders_count: r["orders_count"].to_i, orders_value: r["orders_value"].to_d } }
        .index_by { |r| r[:period] }

      inv_ts = invoices_base
        .group(Arel.sql(trunc_expr("invoice_date", "sales_invoices", grouping)))
        .select(Arel.sql("#{trunc_expr("invoice_date", "sales_invoices", grouping)} AS period, COUNT(*) AS invoices_count, COALESCE(SUM(grand_total), 0) AS invoices_value"))
        .map { |r| { period: r["period"].to_s, invoices_count: r["invoices_count"].to_i, invoices_value: r["invoices_value"].to_d } }
        .index_by { |r| r[:period] }

      all_periods = (orders_ts.keys + inv_ts.keys).uniq.sort
      all_periods.map do |p|
        o = orders_ts[p] || {}
        i = inv_ts[p]    || {}
        {
          period:         p,
          orders_count:   o[:orders_count]   || 0,
          orders_value:   o[:orders_value]   || 0,
          invoices_count: i[:invoices_count] || 0,
          invoices_value: i[:invoices_value] || 0,
        }
      end
    end

    def top_retailers
      invoices_base
        .joins(:customer)
        .group("customers.id, customers.name, customers.code")
        .select("customers.id, customers.name, customers.code, COUNT(*) AS invoices_count, COALESCE(SUM(grand_total), 0) AS total_value")
        .order(Arel.sql("COALESCE(SUM(grand_total), 0) DESC"))
        .limit(10)
        .map do |r|
          {
            id:             r.id,
            name:           r.name,
            code:           r.code,
            invoices_count: r["invoices_count"].to_i,
            total_value:    r["total_value"].to_d,
          }
        end
    end

    def top_products
      SalesInvoiceLine
        .where(sales_invoice_id: invoices_base.select(:id))
        .joins(:product)
        .group("products.id, products.name, products.sku")
        .select("products.id, products.name, products.sku, COALESCE(SUM(sales_invoice_lines.qty), 0) AS total_qty, COALESCE(SUM(sales_invoice_lines.line_total), 0) AS total_value")
        .order(Arel.sql("COALESCE(SUM(sales_invoice_lines.line_total), 0) DESC"))
        .limit(10)
        .map do |r|
          {
            id:          r.id,
            name:        r.name,
            sku:         r.sku,
            total_qty:   r["total_qty"].to_d,
            total_value: r["total_value"].to_d,
          }
        end
    end

    private

    attr_reader :date_from, :date_to, :group_by

    def orders_base
      scope = org_scope(SalesOrder.where(status: SUBMITTED_ORDER_STATUSES))
      scope.where("DATE(submitted_at) BETWEEN ? AND ?", date_from, date_to)
    end

    def invoices_base
      scope = org_scope(SalesInvoice.where(status: "issued"))
      scope.where(invoice_date: date_from..date_to)
    end

    def trunc_expr(col, table, grouping = group_by)
      case grouping.to_s
      when "week"  then "DATE_TRUNC('week', #{table}.#{col})::date"
      when "month" then "DATE_TRUNC('month', #{table}.#{col})::date"
      else              "DATE(#{table}.#{col})"
      end
    end
  end
end