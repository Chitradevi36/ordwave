# frozen_string_literal: true

module Analytics
  # Aggregates return request data for analytics dashboards.
  #
  # Returns shape expected by web/app/insights/returns/page.tsx:
  #   summary:     { total_returns, total_qty, total_value, approval_rate }
  #   by_reason:   [{ reason_code, count, total_qty, total_value, pct_of_total }]
  #   by_month:    [{ month, count, total_value }]
  #   by_product:  [{ product_name, product_sku, count, total_qty, total_value }]
  #   by_customer: [{ customer_name, customer_code, count, total_value }]
  class ReturnsQuery
    def initialize(organization:, branch_id: nil, date_from: nil, date_to: nil)
      @organization = organization
      @branch_id    = branch_id
      @date_from    = date_from&.to_date || 30.days.ago.to_date
      @date_to      = date_to&.to_date   || Date.current
    end

    def summary
      base  = base_scope
      total = base.count
      lines = return_lines_scope

      {
        total_returns: total,
        total_qty:     lines.sum(:qty_reported).to_d.round(3),
        total_value:   base.sum(:credit_note_value).to_d.round(2),
        approval_rate: approval_rate(base)
      }
    end

    def by_reason
      total = base_scope.count.to_f

      return_lines_scope
        .group("return_lines.reason_code")
        .select(
          "return_lines.reason_code AS reason_code",
          "COUNT(DISTINCT return_lines.return_request_id) AS count",
          "SUM(return_lines.qty_reported) AS total_qty",
          "SUM(return_lines.qty_reported * COALESCE(return_lines.unit_price_snapshot, 0)) AS total_value"
        )
        .map do |row|
          cnt = row.count.to_i
          {
            reason_code:  row.reason_code,
            count:        cnt,
            total_qty:    row.total_qty.to_d.round(3),
            total_value:  row.total_value.to_d.round(2),
            pct_of_total: total.zero? ? 0.0 : (cnt / total * 100).round(1)
          }
        end
        .sort_by { |r| -r[:count] }
    end

    def by_month
      base_scope
        .group("TO_CHAR(return_requests.created_at, 'Mon YYYY')")
        .order(Arel.sql("MIN(return_requests.created_at)"))
        .select(
          "TO_CHAR(return_requests.created_at, 'Mon YYYY') AS month",
          "COUNT(*) AS count",
          "SUM(return_requests.credit_note_value) AS total_value"
        )
        .map { |r| { month: r.month, count: r.count.to_i, total_value: r.total_value.to_d.round(2) } }
    end

    def by_product
      return_lines_scope
        .joins(:product)
        .group("products.id, products.name, products.sku")
        .order(Arel.sql("COUNT(DISTINCT return_lines.return_request_id) DESC"))
        .limit(25)
        .select(
          "products.name AS product_name",
          "products.sku  AS product_sku",
          "COUNT(DISTINCT return_lines.return_request_id) AS count",
          "SUM(return_lines.qty_reported) AS total_qty",
          "SUM(return_lines.qty_reported * COALESCE(return_lines.unit_price_snapshot, 0)) AS total_value"
        )
        .map do |r|
          {
            product_name: r.product_name,
            product_sku:  r.product_sku,
            count:        r.count.to_i,
            total_qty:    r.total_qty.to_d.round(3),
            total_value:  r.total_value.to_d.round(2)
          }
        end
    end

    def by_customer
      base_scope
        .joins(:customer)
        .group("customers.id, customers.name, customers.code")
        .order(Arel.sql("COUNT(return_requests.id) DESC"))
        .limit(25)
        .select(
          "customers.name AS customer_name",
          "customers.code AS customer_code",
          "COUNT(return_requests.id) AS count",
          "SUM(return_requests.credit_note_value) AS total_value"
        )
        .map do |r|
          {
            customer_name: r.customer_name,
            customer_code: r.customer_code,
            count:         r.count.to_i,
            total_value:   r.total_value.to_d.round(2)
          }
        end
    end

    private

    def base_scope
      scope = ReturnRequest.not_deleted.for_org(@organization)
                           .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
      scope = scope.where(branch_id: @branch_id) if @branch_id.present?
      scope
    end

    def return_lines_scope
      ReturnLine.joins(:return_request).merge(base_scope)
    end

    def approval_rate(base)
      total = base.count
      return 0.0 if total.zero?

      approved = base.where(status: %w[approved completed]).count.to_f
      (approved / total * 100).round(1)
    end
  end
end
