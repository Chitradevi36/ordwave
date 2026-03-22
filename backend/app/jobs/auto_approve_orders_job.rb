class AutoApproveOrdersJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform
    # Find all organizations with automatic approval mode enabled
    Organization.active.find_each do |organization|
      settings = organization.settings || {}
      approval_mode = settings['order_approval_mode']
      edit_window_minutes = (settings['order_edit_window_minutes'] || 30).to_i

      # Only process if in automatic mode
      next unless approval_mode == 'automatic'

      # Find submitted orders that haven't been edited in the specified window
      cutoff_time = edit_window_minutes.minutes.ago
      submitted_orders = SalesOrder
                           .where(organization: organization)
                           .where(status: 'submitted')
                           .where('updated_at < ?', cutoff_time)
                           .limit(100) # Process in batches to avoid memory issues

      submitted_orders.find_each do |order|
        auto_approve_order(order, organization)
      end

      log_info("Processed #{submitted_orders.count} orders for auto-approval in #{organization.name}")
    end
  end

  private

  def auto_approve_order(order, organization)
    system_user = find_or_create_system_user(organization)

    result = Orders::ApproveOrderService.call(
      actor:    system_user,
      order:    order,
      decision: 'approved',
      reason:   'Auto-approved after edit window expired'
    )

    if result[:ok]
      log_info("Order #{order.order_number} auto-approved in #{organization.name}")
    else
      log_error("Failed to auto-approve order #{order.id} in #{organization.name}: #{result[:errors].join(', ')}")
    end
  rescue StandardError => e
    log_error("Error auto-approving order #{order.id}: #{e.message}")
  end

  def find_or_create_system_user(organization)
    # Use a system user for auto-actions
    User.joins(:memberships)
        .where(memberships: { organization_id: organization.id })
        .joins(memberships: :role)
        .where(roles: { name: 'system' })
        .first || default_approver(organization)
  end

  def default_approver(organization)
    # Fallback to first admin/owner if system user doesn't exist
    User.joins(:memberships)
        .where(memberships: { organization_id: organization.id, active: true })
        .joins(memberships: :role)
        .where(roles: { name: %w[owner admin] })
        .order(:id)
        .first
  end

  def log_info(message)
    Rails.logger.info("[AutoApproveOrdersJob] #{message}")
  end

  def log_error(message)
    Rails.logger.error("[AutoApproveOrdersJob] #{message}")
  end
end
