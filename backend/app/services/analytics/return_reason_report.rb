# frozen_string_literal: true

module Analytics
  # Aggregates return-reason data for dashboards and reports.
  #
  # Usage:
  #   result = Analytics::ReturnReasonReport.call(
  #     organization: org,
  #     from:         30.days.ago,
  #     to:           Date.current
  #   )
  #   result.by_reason       # => [{ reason_code: "expired", count: 42, qty: 210, value: 12500.0 }, ...]
  #   result.by_product      # => [{ product_id: 1, sku: "X", name: "...", count: 10, qty: 50 }, ...]
  #   result.by_customer     # => [{ customer_id: 1, name: "...", count: 8, qty: 30 }, ...]
  #   result.summary         # => { total_returns: 120, total_qty: 600, total_value: 45000.0 }
  #
  class ReturnReasonReport
    Result = Struct.new(:success?, :by_reason, :by_product, :by_customer, :by_month, :summary, :errors)

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
      base = return_lines_scope

      Result.new(
        true,
        aggregate_by_reason(base),
        aggregate_by_product(base),
        aggregate_by_customer(base),
        aggregate_by_month(base),
        compute_summary(base),
        []
      )
    rescue StandardError => e
      Result.new(false, [], [], [], [], {}, [e.message])
    end

    private

    def return_lines_scope
      scope = ReturnLine
                .joins(return_request: :organization)
                .where(return_requests: { organization_id: @organization.id })
                .where(return_requests: { created_at: @from..@to })

      scope = scope.where(return_requests: { branch_id: @branch.id }) if @branch
      scope
    end

    def aggregate_by_reason(base)
      base
        .group(:reason_code)
        .select(
          "return_lines.reason_code",
          "COUNT(*) AS count",
          "SUM(return_lines.qty_reported) AS total_qty",
          "SUM(return_lines.qty_reported * return_lines.unit_price_snapshot) AS total_value"
        )
        .map do |row|
          {
            reason_code: row.reason_code,
            count:       row.count.to_i,
            qty:         row.total_qty.to_d,
            value:       row.total_value.to_d.round(2)
          }
        end
        .sort_by { |r| -r[:count] }
    end

    def aggregate_by_product(base)
      base
        .joins(:product)
        .group("products.id", "products.sku", "products.name")
        .select(
          "products.id   AS product_id",
          "products.sku  AS product_sku",
          "products.name AS product_name",
          "COUNT(*)                     AS count",
          "SUM(return_lines.qty_reported) AS total_qty"
        )
        .order("count DESC")
        .limit(50)
        .map do |row|
          {
            product_id: row.product_id,
            sku:        row.product_sku,
            name:       row.product_name,
            count:      row.count.to_i,
            qty:        row.total_qty.to_d
          }
        end
    end

    def aggregate_by_customer(base)
      base
        .joins(return_request: :customer)
        .group("customers.id", "customers.name")
        .select(
          "customers.id   AS customer_id",
          "customers.name AS customer_name",
          "COUNT(*)                     AS count",
          "SUM(return_lines.qty_reported) AS total_qty"
        )
        .order("count DESC")
        .limit(50)
        .map do |row|
          {
            customer_id: row.customer_id,
            name:        row.customer_name,
            count:       row.count.to_i,
            qty:         row.total_qty.to_d
          }
        end
    end

    def aggregate_by_month(base)
      base
        .joins(:return_request)
        .group("DATE_TRUNC('month', return_requests.created_at)")
        .select(
          "DATE_TRUNC('month', return_requests.created_at) AS month",
          "COUNT(*)                     AS count",
          "SUM(return_lines.qty_reported) AS total_qty",
          "SUM(return_lines.qty_reported * return_lines.unit_price_snapshot) AS total_value"
        )
        .order("month ASC")
        .map do |row|
          {
            month: row.month.strftime('%Y-%m'),
            count: row.count.to_i,
            qty:   row.total_qty.to_d,
            value: row.total_value.to_d.round(2)
          }
        end
    end

    def compute_summary(base)
      stats = base.select(
        "COUNT(DISTINCT return_lines.return_request_id) AS total_returns",
        "COUNT(*)                     AS total_lines",
        "COALESCE(SUM(return_lines.qty_reported), 0) AS total_qty",
        "COALESCE(SUM(return_lines.qty_reported * return_lines.unit_price_snapshot), 0) AS total_value"
      ).take

      {
        total_returns: stats.total_returns.to_i,
        total_lines:   stats.total_lines.to_i,
        total_qty:     stats.total_qty.to_d,
        total_value:   stats.total_value.to_d.round(2)
      }
    end
  end
end
