# frozen_string_literal: true

module Analytics
  class InventoryHealthQuery < BaseQuery
    DEAD_STOCK_DAYS  = 90
    FAST_MOVING_DAYS = 30

    def initialize(organization:, branch_id: nil)
      super(organization: organization, branch_id: branch_id)
    end

    # Stat-card summary
    def summary
      {
        low_stock_count:   low_stock_relation.count,
        dead_stock_count:  dead_stock_relation.count,
        total_skus:        inventory_base.count,
        zero_stock_count:  inventory_base.where("qty_on_hand <= ?", 0).count,
      }
    end

    # Products where available stock (on_hand − reserved) < threshold and threshold is set
    def low_stock
      low_stock_relation
        .joins(:product)
        .select(
          "inventory_levels.id",
          "inventory_levels.product_id",
          "products.name AS product_name",
          "products.sku AS product_sku",
          "inventory_levels.qty_on_hand",
          "inventory_levels.qty_reserved",
          "inventory_levels.min_qty_threshold",
          "(inventory_levels.qty_on_hand - inventory_levels.qty_reserved) AS qty_available"
        )
        .order(Arel.sql("(inventory_levels.qty_on_hand - inventory_levels.qty_reserved) ASC"))
        .map do |r|
          {
            id:                r.id,
            product_id:        r.product_id,
            product_name:      r["product_name"],
            product_sku:       r["product_sku"],
            qty_on_hand:       r.qty_on_hand.to_d,
            qty_reserved:      r.qty_reserved.to_d,
            qty_available:     r["qty_available"].to_d,
            min_qty_threshold: r.min_qty_threshold.to_d,
          }
        end
    end

    # Products in this org/branch that have had no invoice lines in the last 90 days
    # but still have stock on hand
    def dead_stock
      dead_stock_relation
        .joins(:product)
        .select(
          "inventory_levels.id",
          "inventory_levels.product_id",
          "products.name AS product_name",
          "products.sku  AS product_sku",
          "inventory_levels.qty_on_hand",
          "inventory_levels.qty_reserved"
        )
        .order(qty_on_hand: :desc)
        .map do |r|
          {
            id:           r.id,
            product_id:   r.product_id,
            product_name: r["product_name"],
            product_sku:  r["product_sku"],
            qty_on_hand:  r.qty_on_hand.to_d,
            qty_reserved: r.qty_reserved.to_d,
          }
        end
    end

    # Top 20 products by quantity sold in the last 30 days
    def fast_moving
      cutoff = FAST_MOVING_DAYS.days.ago.to_date

      SalesInvoiceLine
        .where(sales_invoice_id: invoices_issued_since(cutoff).select(:id))
        .joins(:product)
        .group("products.id, products.name, products.sku")
        .select(
          "products.id",
          "products.name",
          "products.sku",
          "COALESCE(SUM(sales_invoice_lines.qty), 0) AS total_qty",
          "COALESCE(SUM(sales_invoice_lines.line_total), 0) AS total_value"
        )
        .order(Arel.sql("COALESCE(SUM(sales_invoice_lines.qty), 0) DESC"))
        .limit(20)
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

    def inventory_base
      scope = InventoryLevel.where(organization_id: org_id)
      scope = scope.where(branch_id: branch_id) if branch_id.present?
      scope
    end

    def low_stock_relation
      inventory_base
        .where.not(min_qty_threshold: nil)
        .where("qty_on_hand - qty_reserved < min_qty_threshold")
    end

    def dead_stock_relation
      cutoff = DEAD_STOCK_DAYS.days.ago.to_date

      branch_clause = branch_id.present? ? "AND si.branch_id = #{branch_id.to_i}" : ""

      inventory_base
        .where("qty_on_hand > ?", 0)
        .where(
          "NOT EXISTS (
            SELECT 1 FROM sales_invoice_lines sil
            INNER JOIN sales_invoices si ON si.id = sil.sales_invoice_id
            WHERE sil.product_id      = inventory_levels.product_id
              AND si.status           = 'issued'
              AND si.organization_id  = #{org_id}
              AND si.invoice_date    >= '#{cutoff}'
              #{branch_clause}
          )"
        )
    end

    def invoices_issued_since(date)
      scope = SalesInvoice.where(status: "issued", organization_id: org_id)
                          .where("invoice_date >= ?", date)
      scope = scope.where(branch_id: branch_id) if branch_id.present?
      scope
    end
  end
end
