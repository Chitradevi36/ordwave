module Customers
  # Returns a compact dashboard payload for customer users.
  # Usage: Customers::DashboardService.call(customer: customer, branch: branch)
  class DashboardService
    def self.call(customer:, branch:)
      new(customer: customer, branch: branch).call
    end

    def initialize(customer:, branch:)
      @customer = customer
      @branch   = branch
      @org      = customer.organization
    end

    def call
      {
        customer: customer_summary,
        credit:   credit_summary,
        recent_orders: recent_orders.map { |o| summarize_order(o) },
        outstanding_invoices: outstanding_invoices_summary,
        notifications: notifications_summary
      }
    end

    private

    def customer_summary
      {
        id: @customer.id,
        name: @customer.name,
        phone: @customer.phone,
        status: @customer.status
      }
    end

    def credit_summary
      ca = @customer.credit_account
      return { available: nil, limit: nil, current_balance: nil, blocked: false } unless ca

      {
        limit: ca.credit_limit.to_f,
        available: ca.available_credit.to_f,
        current_balance: ca.current_balance.to_f,
        blocked: @customer.credit_block_rule == 'hard_block'
      }
    end

    def recent_orders
      SalesOrder.where(customer: @customer)
                .where.not(status: %w[cancelled rejected])
                .order(created_at: :desc)
                .limit(3)
    end

    def summarize_order(o)
      {
        id: o.id,
        order_number: o.order_number,
        status: o.status,
        total_amount: o.total_amount.to_f,
        submitted_at: o.submitted_at,
        credit_decision: o.credit_decision,
        credit_snapshot: o.credit_snapshot || {},
        small_lines: o.lines.limit(3).map { |l| { product_id: l.product_id, name: l.product&.name, qty: l.qty, unit_price: l.unit_price.to_f } }
      }
    end

    def outstanding_invoices_summary
      invs = @customer.sales_invoices.not_deleted.where(status: %w[pending issued])
      {
        count: invs.count,
        total_outstanding: invs.sum(:grand_total).to_f
      }
    end

    def notifications_summary
      # Lightweight: count unread notifications for this customer across org
      if defined?(Notification) && @customer.respond_to?(:id)
        Notification.for_org(@org.id).where(notifiable_type: 'Customer', notifiable_id: @customer.id).unread.count
      else
        0
      end
    end
  end
end
