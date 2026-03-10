module Api
  module V1
    module Inventory
      class AlertsController < BaseController
        before_action :require_organization!

        # POST /api/v1/inventory/check_low_stock
        # Enqueues CheckLowStockJob for the current organization.
        # Useful for admin dashboards and manual triggers.
        def check_low_stock
          authorize :inventory_alert, :manage?
          CheckLowStockJob.enqueue_for_org(current_organization.id)
          render_success({ queued: true, organization_id: current_organization.id })
        end
      end
    end
  end
end
