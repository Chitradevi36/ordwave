# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/delivery_rejections
    # Org-wide list of all DeliveryRejection records with filtering by reason_code,
    # date range, auto_return flag, and pending-return status.
    class DeliveryRejectionsController < BaseController
      before_action :require_organization!

      def index
        authorize DeliveryRejection.new, :index?

        base = base_scope

        base = base.by_reason(params[:reason_code])              if params[:reason_code].present?
        base = base.where(auto_return: true)                     if params[:auto_return] == 'true'
        base = base.pending_return                               if params[:pending_return] == 'true'
        base = base.where(condition: params[:condition])         if params[:condition].present?
        base = filter_by_date_range(base)

        items   = paginate(base.order(created_at: :desc))
        summary = build_summary

        render_success(
          items.map { |r| serialize(r) },
          meta: pagination_meta(items).merge(summary: summary)
        )
      end

      private

      def base_scope
        DeliveryRejection
          .joins(trip_stop: :delivery_trip)
          .where(delivery_trips: { organization: current_organization })
          .includes(:product, :rejected_by, :return_request,
                    trip_stop: [:delivery_trip],
                    sales_order: [:customer])
      end

      def filter_by_date_range(scope)
        if params[:from_date].present?
          scope = scope.where('delivery_rejections.created_at >= ?',
                              params[:from_date].to_date.beginning_of_day)
        end
        if params[:to_date].present?
          scope = scope.where('delivery_rejections.created_at <= ?',
                              params[:to_date].to_date.end_of_day)
        end
        scope
      rescue ArgumentError
        scope
      end

      def build_summary
        base = base_scope

        {
          total_rejections:   base.count,
          by_reason:          base.group(:reason_code).count,
          auto_return_count:  base.where(auto_return: true).count,
          pending_return_count: base.pending_return.count,
          total_qty_rejected: base.sum(:qty_rejected).to_f
        }
      end

      def serialize(r)
        {
          id:            r.id,
          qty_rejected:  r.qty_rejected.to_f,
          reason_code:   r.reason_code,
          condition:     r.condition,
          notes:         r.notes,
          auto_return:   r.auto_return,
          created_at:    r.created_at,
          product: {
            id:   r.product.id,
            name: r.product.name,
            sku:  r.product.sku
          },
          order: {
            id:           r.sales_order.id,
            order_number: r.sales_order.order_number,
            customer_name: r.sales_order.customer.name
          },
          trip: {
            id:          r.trip_stop.delivery_trip.id,
            trip_number: r.trip_stop.delivery_trip.trip_number,
            trip_date:   r.trip_stop.delivery_trip.trip_date
          },
          rejected_by: {
            id:   r.rejected_by.id,
            name: r.rejected_by.name
          },
          return_request_id: r.return_request_id
        }
      end
    end
  end
end
