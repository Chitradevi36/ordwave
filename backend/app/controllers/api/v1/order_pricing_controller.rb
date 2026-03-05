module Api
  module V1
    # Price preview endpoint — returns base prices + scheme discounts for a
    # proposed cart without creating a draft order.
    #
    # POST /api/v1/order_pricing/preview
    # Body:
    #   {
    #     customer_id: 123,
    #     branch_id:   5,
    #     lines:       [{ product_id: 1, qty: 10 }, ...],
    #     context:     { route_id: 2, beat_id: nil, date: "2026-03-05" }
    #   }
    #
    class OrderPricingController < BaseController
      before_action :require_organization!

      skip_after_action :verify_policy_scoped

      # POST /api/v1/order_pricing/preview
      def preview
        authorize current_user, policy_class: UserPolicy

        customer = current_organization.customers.find(params[:customer_id])
        branch   = current_organization.branches.find(params[:branch_id] || current_organization.branches.first&.id)

        result = SalesOrders::PricePreviewService.call(
          retailer: customer,
          branch:   branch,
          lines:    Array(params[:lines]),
          context:  {
            route_id: params.dig(:context, :route_id),
            beat_id:  params.dig(:context, :beat_id),
            date:     params.dig(:context, :date)
          }
        )

        render_success({
          lines:           result.lines,
          freebies:        result.freebies,
          order_discounts: result.order_discounts,
          totals:          result.totals,
          explain:         result.explain
        })
      rescue ActiveRecord::RecordNotFound => e
        render_errors([e.message], status: :not_found)
      rescue StandardError => e
        Rails.logger.error("[OrderPricingController] preview error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        render_errors(["Price preview failed: #{e.message}"], status: :unprocessable_entity)
      end
    end
  end
end
