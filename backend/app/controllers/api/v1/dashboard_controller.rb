# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/dashboard
    # Single-shot founder dashboard payload: every KPI, trends, alerts, top lists.
    class DashboardController < BaseController
      before_action :require_organization!
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def show
        authorize current_user, :index?, policy_class: UserPolicy

        today      = Date.current
        mtd_start  = today.beginning_of_month
        prev_start = (today - 1.month).beginning_of_month
        prev_end   = (today - 1.month).end_of_month
        org        = current_organization
        bid        = params[:branch_id].presence&.to_i

        data = Rails.cache.fetch(cache_key("dashboard/#{today}/#{bid}"), expires_in: 3.minutes) do
          build_payload(org, bid, today, mtd_start, prev_start, prev_end)
        end

        render_success(data)
      end

      private

      # ── Main builder ─────────────────────────────────────────────────────

      def build_payload(org, bid, today, mtd_start, prev_start, prev_end)
        oid = org.id

        # ── Revenue / Orders ────────────────────────────────────────────────
        orders_base = lambda { |from, to, statuses = %w[submitted approved on_hold dispatched delivered]|
          scope = SalesOrder.where(organization_id: oid, status: statuses)
          scope = scope.where(branch_id: bid) if bid.present?
          scope.where("DATE(submitted_at) BETWEEN ? AND ?", from, to)
        }

        invoices_base = lambda { |from, to|
          scope = SalesInvoice.where(organization_id: oid, status: "issued")
          scope = scope.where(branch_id: bid) if bid.present?
          scope.where(invoice_date: from..to)
        }

        # MTD
        mtd_orders     = orders_base.call(mtd_start, today)
        mtd_inv        = invoices_base.call(mtd_start, today)
        mtd_revenue    = mtd_inv.sum(:grand_total).to_d

        # Previous month (same-day fraction for fair comparison)
        elapsed_days   = (today - mtd_start).to_i + 1
        prev_end_adj   = [prev_start + elapsed_days - 1, prev_end].min
        prev_inv       = invoices_base.call(prev_start, prev_end_adj)
        prev_revenue   = prev_inv.sum(:grand_total).to_d

        revenue_delta  = prev_revenue.zero? ? nil : ((mtd_revenue - prev_revenue) / prev_revenue * 100).round(1)

        # Today orders
        today_orders   = orders_base.call(today, today)
        yest_orders    = orders_base.call(today - 1, today - 1)

        on_hold_orders = SalesOrder.where(organization_id: oid).tap { |s|
                           s.merge!(SalesOrder.where(branch_id: bid)) if bid.present?
                         }.where(status: "on_hold")
        pending_orders = SalesOrder.where(organization_id: oid).tap { |s|
                           s.merge!(SalesOrder.where(branch_id: bid)) if bid.present?
                         }.where(status: "submitted")

        # Rebuild cleanly
        on_hold_count  = SalesOrder.where(organization_id: oid, status: "on_hold")
                                   .then { |s| bid.present? ? s.where(branch_id: bid) : s }
                                   .count
        pending_count  = SalesOrder.where(organization_id: oid, status: "submitted")
                                   .then { |s| bid.present? ? s.where(branch_id: bid) : s }
                                   .count
        approved_count = SalesOrder.where(organization_id: oid, status: "approved")
                                   .then { |s| bid.present? ? s.where(branch_id: bid) : s }
                                   .count

        # ── Collections ─────────────────────────────────────────────────────
        payments_scope = lambda { |from, to|
          scope = Payment.where(organization_id: oid, status: "confirmed")
          scope = scope.where(branch_id: bid) if bid.present?
          scope.where(received_date: from..to)
        }

        today_payments = payments_scope.call(today, today).sum(:amount).to_d
        mtd_payments   = payments_scope.call(mtd_start, today).sum(:amount).to_d

        unpaid_scope   = SalesInvoice.where(organization_id: oid, status: "issued")
                                     .then { |s| bid.present? ? s.where(branch_id: bid) : s }
                                     .where("outstanding_amount > 0")

        outstanding_amount = unpaid_scope.sum(:outstanding_amount).to_d
        overdue_amount     = unpaid_scope.where("due_date < ?", today).sum(:outstanding_amount).to_d
        collection_rate    = mtd_revenue.zero? ? 0.0 : (mtd_payments / mtd_revenue * 100).round(1)

        # ── Inventory ────────────────────────────────────────────────────────
        inv_scope     = InventoryLevel.where(organization_id: oid)
        inv_scope     = inv_scope.where(branch_id: bid) if bid.present?

        low_stock_count  = inv_scope.where.not(min_qty_threshold: nil)
                                    .where("qty_on_hand - qty_reserved < min_qty_threshold").count
        zero_stock_count = inv_scope.where("qty_on_hand <= 0").count
        dead_stock_count = Analytics::InventoryHealthQuery.new(organization: org, branch_id: bid).send(:dead_stock_relation).count

        # ── Credit risk ──────────────────────────────────────────────────────
        credit_scope  = CreditAccount.joins(:customer)
                                     .where(customers: { organization_id: oid })
        credit_scope  = credit_scope.where(credit_accounts: { branch_id: bid }) if bid.present?

        risky_accounts   = credit_scope.where("overdue_amount > 0 OR hold_required = true OR watchlist = true").count
        blocked_accounts = credit_scope.where(hold_required: true).count
        total_overdue_cr = credit_scope.sum(:overdue_amount).to_d

        # ── Active schemes ───────────────────────────────────────────────────
        active_schemes = Scheme.where(organization_id: oid, status: "active")
                               .then { |s| bid.present? ? s.where("branch_id IS NULL OR branch_id = ?", bid) : s }
                               .valid_on(today).count

        # ── Timeseries: last 30 days (orders_value + collections) ────────────
        ts_start = today - 29
        ts_days  = (ts_start..today).to_a

        orders_ts = SalesOrder
          .where(organization_id: oid, status: %w[submitted approved on_hold dispatched delivered])
          .then { |s| bid.present? ? s.where(branch_id: bid) : s }
          .where("DATE(submitted_at) BETWEEN ? AND ?", ts_start, today)
          .group(Arel.sql("DATE(submitted_at)"))
          .pluck(Arel.sql("DATE(submitted_at)"), Arel.sql("COALESCE(SUM(total_amount), 0)"))
          .to_h

        col_ts = Payment
          .where(organization_id: oid, status: "confirmed")
          .then { |s| bid.present? ? s.where(branch_id: bid) : s }
          .where(received_date: ts_start..today)
          .group(:received_date)
          .pluck(:received_date, Arel.sql("COALESCE(SUM(amount), 0)"))
          .to_h

        timeseries = ts_days.map do |d|
          {
            date:             d.to_s,
            orders_value:     orders_ts[d].to_d,
            collections:      col_ts[d].to_d,
          }
        end

        # ── Top customers (MTD by invoice value) ─────────────────────────────
        top_customers = mtd_inv
          .joins(:customer)
          .group(Arel.sql("customers.id, customers.name, customers.code"))
          .select(Arel.sql("customers.id, customers.name, customers.code, COUNT(*) AS inv_count, COALESCE(SUM(grand_total), 0) AS revenue"))
          .order(Arel.sql("COALESCE(SUM(grand_total), 0) DESC"))
          .limit(5)
          .map { |r| { id: r.id, name: r.name, code: r.code, invoice_count: r["inv_count"].to_i, revenue_mtd: r["revenue"].to_d } }

        # ── Top products (MTD by invoice line value) ─────────────────────────
        top_products = SalesInvoiceLine
          .where(sales_invoice_id: mtd_inv.select(:id))
          .joins(:product)
          .group(Arel.sql("products.id, products.name, products.sku"))
          .select(Arel.sql("products.id, products.name, products.sku, COALESCE(SUM(qty), 0) AS qty_mtd, COALESCE(SUM(line_total), 0) AS revenue_mtd"))
          .order(Arel.sql("COALESCE(SUM(line_total), 0) DESC"))
          .limit(5)
          .map { |r| { id: r.id, name: r.name, sku: r.sku, qty_mtd: r["qty_mtd"].to_d, revenue_mtd: r["revenue_mtd"].to_d } }

        # ── Alerts (actionable items for the owner) ──────────────────────────
        alerts = []
        alerts << { type: "on_hold",   severity: "high",   count: on_hold_count,  label: "order#{"s" if on_hold_count != 1} on hold",   href: "/orders?status=on_hold" }  if on_hold_count > 0
        alerts << { type: "pending",   severity: "medium", count: pending_count,  label: "order#{"s" if pending_count != 1} awaiting approval", href: "/orders?status=submitted" } if pending_count > 0
        alerts << { type: "overdue",   severity: "high",   count: unpaid_scope.where("due_date < ?", today).count, label: "overdue invoice#{"s" if unpaid_scope.where("due_date < ?", today).count != 1}", href: "/finance" } if overdue_amount > 0
        alerts << { type: "low_stock", severity: "medium", count: low_stock_count, label: "product#{"s" if low_stock_count != 1} below reorder level", href: "/inventory/stock" } if low_stock_count > 0
        alerts << { type: "blocked",   severity: "high",   count: blocked_accounts, label: "account#{"s" if blocked_accounts != 1} on credit hold", href: "/approvals/credit-limits" } if blocked_accounts > 0

        {
          as_of:           Time.current.iso8601,
          greeting_name:   current_user.first_name,
          org_name:        org.name,
          revenue: {
            mtd:             mtd_revenue,
            prev_mtd:        prev_revenue,
            delta_pct:       revenue_delta,
            today_invoiced:  invoices_base.call(today, today).sum(:grand_total).to_d,
          },
          orders: {
            today:      today_orders.count,
            yesterday:  yest_orders.count,
            mtd:        mtd_orders.count,
            on_hold:    on_hold_count,
            pending:    pending_count,
            approved:   approved_count,
          },
          collections: {
            today:           today_payments,
            mtd:             mtd_payments,
            outstanding:     outstanding_amount,
            overdue:         overdue_amount,
            collection_rate: collection_rate,
          },
          inventory: {
            low_stock:   low_stock_count,
            dead_stock:  dead_stock_count,
            zero_stock:  zero_stock_count,
          },
          credit: {
            risky_accounts:   risky_accounts,
            blocked_accounts: blocked_accounts,
            total_overdue:    total_overdue_cr,
          },
          active_schemes:  active_schemes,
          alerts:          alerts,
          timeseries:      timeseries,
          top_customers:   top_customers,
          top_products:    top_products,
        }
      end

      def cache_key(segment)
        [
          "dashboard",
          current_organization.id,
          segment,
        ].join("/")
      end
    end
  end
end
