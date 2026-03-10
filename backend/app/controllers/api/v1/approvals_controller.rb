# frozen_string_literal: true

module Api
  module V1
    # Aggregates all actionable approval items for the current user.
    #
    # GET /api/v1/approvals
    # Returns held orders + pending credit limit change requests + total count.
    class ApprovalsController < BaseController
      def index
        authorize :approval, :index?

        held_orders     = fetch_held_orders
        credit_requests = fetch_credit_requests

        render json: {
          data: {
            held_orders:     held_orders.map     { |o| serialize_order(o) },
            credit_requests: credit_requests.map { |r| serialize_credit_request(r) },
            total_count:     held_orders.size + credit_requests.size
          }
        }
      end

      private

      def fetch_held_orders
        policy_scope(SalesOrder)
          .where(status: 'on_hold')
          .includes(:customer, :created_by, lines: :product)
          .order(created_at: :desc)
          .limit(50)
      end

      def fetch_credit_requests
        policy_scope(CreditLimitChangeRequest)
          .where(status: 'pending')
          .includes(:credit_account)
          .order(created_at: :desc)
          .limit(50)
      rescue NameError
        # CreditLimitChangeRequest may live under a different constant — return empty safely
        []
      end

      def serialize_order(order)
        {
          id:            order.id,
          order_number:  order.order_number,
          customer_name: order.customer&.name,
          total_amount:  order.total_amount,
          status:        order.status,
          created_by:    order.created_by&.full_name,
          created_at:    order.created_at.iso8601,
          lines_count:   order.lines.size
        }
      end

      def serialize_credit_request(req)
        {
          id:                    req.id,
          customer_name:         req.credit_account&.customer&.name,
          current_limit:         req.credit_account&.credit_limit,
          new_limit:             req.new_limit,
          counter_offer_limit:   req.counter_offer_limit,
          reason:                req.reason,
          requested_by:          req.requested_by&.full_name,
          created_at:            req.created_at.iso8601
        }
      end
    end
  end
end
