# frozen_string_literal: true

module Analytics
  class CollectionsSummaryQuery < BaseQuery
    attr_reader :date_from, :date_to

    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil)
      super(organization: organization, branch_id: branch_id)
      @date_from = parse_date(date_from, MTD_BEGIN.call)
      @date_to   = parse_date(date_to,   TODAY.call)
    end

    # Full summary for the collection dashboard stat cards
    def summary
      inv_value = invoices_issued_in_period.sum(:grand_total).to_d
      col_value = payments_base
                    .where(received_date: date_from..date_to)
                    .sum(:amount).to_d

      {
        payments_today:        payments_today,
        payments_mtd:          payments_mtd,
        payments_period:       col_value,
        unpaid_invoices_count: unpaid_invoices.count,
        unpaid_invoices_value: unpaid_invoices.sum(:outstanding_amount).to_d,
        collection_rate:       pct(col_value, inv_value),
      }
    end

    # Time-series of confirmed payments grouped by received_date
    def timeseries(grouping: "day")
      trunc = case grouping.to_s
              when "week"  then "DATE_TRUNC('week', received_date)"
              when "month" then "DATE_TRUNC('month', received_date)"
              else              "received_date"
              end

      payments_base
        .where(received_date: date_from..date_to)
        .group(Arel.sql(trunc))
        .order(Arel.sql("1"))
        .pluck(Arel.sql("#{trunc} AS period, COALESCE(SUM(amount), 0) AS total_amount, COUNT(*) AS count"))
        .map { |period, amount, count| { period: period, amount: amount.to_d, count: count } }
    end

    # Top 10 collectors (created_by_id → user name) in period
    def top_collectors
      payments_base
        .where(received_date: date_from..date_to)
        .joins("INNER JOIN users ON users.id = payments.created_by_id")
        .group("users.id, users.first_name, users.last_name")
        .select("users.id, users.first_name, users.last_name, COALESCE(SUM(payments.amount), 0) AS total_collected, COUNT(*) AS payment_count")
        .order(Arel.sql("COALESCE(SUM(payments.amount), 0) DESC"))
        .limit(10)
        .map do |r|
          {
            id:              r.id,
            name:            "#{r.first_name} #{r.last_name}".strip,
            total_collected: r["total_collected"].to_d,
            payment_count:   r["payment_count"].to_i,
          }
        end
    end

    # Paginated list of unpaid invoices (outstanding_amount > 0)
    # Returns an ActiveRecord::Relation — caller paginates
    def unpaid_invoices_relation
      unpaid_invoices
        .joins(:customer)
        .select("sales_invoices.*, customers.name AS customer_name")
        .order(outstanding_amount: :desc)
    end

    private

    # ── Base scopes ───────────────────────────────────────────────────────────

    def payments_base
      scope = Payment.where(status: "confirmed", organization_id: org_id)
      scope = scope.where(branch_id: branch_id) if branch_id.present?
      scope
    end

    def payments_today
      payments_base.where(received_date: TODAY.call).sum(:amount).to_d
    end

    def payments_mtd
      payments_base.where(received_date: MTD_BEGIN.call..TODAY.call).sum(:amount).to_d
    end

    def invoices_issued_in_period
      scope = SalesInvoice.where(status: "issued", organization_id: org_id)
                          .where(invoice_date: date_from..date_to)
      scope = scope.where(branch_id: branch_id) if branch_id.present?
      scope
    end

    def unpaid_invoices
      scope = SalesInvoice.where(status: "issued", organization_id: org_id)
                          .where("outstanding_amount > ?", 0)
      scope = scope.where(branch_id: branch_id) if branch_id.present?
      scope
    end
  end
end
