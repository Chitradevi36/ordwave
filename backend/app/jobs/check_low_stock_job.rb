class CheckLowStockJob < ApplicationJob
  queue_as :low

  # Runs nightly (scheduled via sidekiq-cron) or on stock change (enqueue_for_org).
  # Notifies warehouse staff and managers when inventory drops below min_qty_threshold.
  #
  # Sidekiq-cron entry (config/sidekiq.yml or initializer):
  #   every_night_low_stock:
  #     cron: '0 2 * * *'   # 2 AM daily
  #     class: CheckLowStockJob
  #     args: []             # all orgs
  #
  # Single-org trigger (e.g. after stock movement):
  #   CheckLowStockJob.perform_later(organization_id)
  #
  def self.enqueue_for_org(org_id)
    perform_later(org_id)
  end

  def perform(organization_id = nil)
    scope = organization_id.present? ?
            Organization.active.where(id: organization_id) :
            Organization.active

    scope.find_each { |org| check_org(org) }
  end

  private

  def check_org(org)
    low_stock_items = InventoryLevel
      .where(organization: org)
      .where('qty_on_hand <= min_qty_threshold AND min_qty_threshold > 0')
      .includes(:product, :branch)

    return if low_stock_items.empty?

    recipients = org.memberships.active
                    .joins(:role)
                    .where(roles: { name: %w[warehouse_staff manager owner admin] })
                    .map(&:user)
                    .uniq
                    .compact

    return if recipients.empty?

    preview_names = low_stock_items.limit(5).map do |il|
      unit = il.product.units_of_measure&.symbol
      "#{il.product.name}: #{il.qty_on_hand}#{unit ? " #{unit}" : ''}"
    end

    Notifications::CreateService.new(
      organization: org,
      recipients:   recipients,
      actor:        nil,
      notifiable:   nil,
      type:         'stock_low',
      title:        "#{low_stock_items.count} items below stock threshold",
      body:         preview_names.join(', '),
      deep_link:    '/inventory/stock?filter=low_stock',
      severity:     'medium'
    ).call

    # Fire webhook for each low-stock item
    low_stock_items.each do |il|
      WebhookEvents.fire(
        organization: org,
        event:        'inventory.low_stock',
        payload:      WebhookEvents.low_stock_payload(
          product:         il.product,
          inventory_level: il,
          threshold:       il.min_qty_threshold
        )
      )
    end
  rescue StandardError => e
    Rails.logger.error "[CheckLowStockJob] org=#{org.id}: #{e.message}"
  end
end
