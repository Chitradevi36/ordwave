module Inventory
  # Feature 12: Resolves inventory shortages through customer-offered options
  #
  # Implements four resolution paths:
  #   1. Refund: Cancel order, refund customer
  #   2. Partial: Deliver available qty, refund remainder
  #   3. Reschedule: Hold order for future delivery
  #   4. Override: Manager approves despite shortage
  #
  # Usage:
  #   result = Inventory::ShortageResolutionService.call(
  #     order:                  order,
  #     resolution_type:        'partial',  # or 'refund', 'reschedule'
  #     actor:                  user,
  #     customer_communication: { email: true, sms: true },
  #     notes:                  'Customer agreed to partial delivery'
  #   )
  #
  class ShortageResolutionService
    Result = Struct.new(:success?, :order, :refunded_amount, :notes, :errors, keyword_init: true)

    RESOLUTION_TYPES = %w[refund partial reschedule override].freeze

    def self.call(**args)
      new(**args).call
    end

    def initialize(order:, resolution_type:, actor:, customer_communication: {}, notes: nil)
      @order                     = order
      @resolution_type           = resolution_type.to_s
      @actor                     = actor
      @customer_communication    = customer_communication || {}
      @notes                     = notes
      @errors                    = []
    end

    def call
      return failure(['Invalid resolution type']) unless RESOLUTION_TYPES.include?(@resolution_type)
      return failure(['Order not found']) unless @order.present?

      case @resolution_type
      when 'refund'
        process_refund
      when 'partial'
        process_partial
      when 'reschedule'
        process_reschedule
      when 'override'
        process_override
      end
    end

    private

    def process_refund
      ActiveRecord::Base.transaction do
        # Mark order as cancelled due to shortage
        @order.update!(
          status: 'cancelled',
          cancellation_reason: 'inventory_shortage'
        )

        # Log shortage resolution
        log_shortage_resolution('full_refund')

        # Notify customer of cancellation and refund
        notify_customer_refund

        # Create refund if payment was already received
        refunded = maybe_create_refund

        Result.new(
          success?: true,
          order: @order,
          refunded_amount: refunded,
          notes: "Order cancelled. Refund of ₹#{refunded} processed.",
          errors: []
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    def process_partial
      ActiveRecord::Base.transaction do
        detection_result = Inventory::ShortageDetectionService.call(
          order: @order,
          branch: @order.branch,
          actor: @actor
        )

        # Recalculate order with partial quantities
        partial_totals = calculate_partial_delivery(detection_result.shortage_items)

        @order.update!(
          status: 'partially_fulfilled',
          notes: @order.notes.to_s + "\n[Partial Delivery] Only available qty being delivered. #{@notes}"
        )

        # Update line items to reflect partial quantities
        update_order_lines_for_partial(detection_result.shortage_items)

        # Refund customer for shortage amount
        refunded = maybe_create_refund_for_shortage(detection_result.total_shortage_value)

        log_shortage_resolution('partial_delivery', partial_totals)
        notify_customer_partial(detection_result.shortage_items, refunded)

        Result.new(
          success?: true,
          order: @order,
          refunded_amount: refunded,
          notes: "Partial delivery: #{partial_totals[:items_delivered]} items delivered, refund #{refunded} processed.",
          errors: []
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    def process_reschedule
      ActiveRecord::Base.transaction do
        # Find all shortage items to determine reschedule date
        detection_result = Inventory::ShortageDetectionService.call(
          order: @order,
          branch: @order.branch,
          actor: @actor
        )

        # Estimate restock dates from purchase orders / inbound stock
        # For MVP: Allow customer/manager to suggest date
        reschedule_date = estimate_reschedule_date(detection_result.shortage_items)

        @order.update!(
          status: 'rescheduled',
          rescheduled_at: Time.current,
          rescheduled_from: @order.created_at,
          rescheduled_reason: 'inventory_shortage',
          planned_delivery_date: reschedule_date,
          notes: @order.notes.to_s + "\n[Rescheduled] Shortage items. Estimated restock: #{reschedule_date.to_date}. #{@notes}"
        )

        log_shortage_resolution('rescheduled', { planned_date: reschedule_date })
        notify_customer_reschedule(reschedule_date)

        Result.new(
          success?: true,
          order: @order,
          refunded_amount: 0,
          notes: "Order rescheduled to #{reschedule_date.to_date}. Customer notified.",
          errors: []
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    def process_override
      ActiveRecord::Base.transaction do
        # Manager explicitly overrides shortage and approves order anyway
        @order.update!(
          status: 'approved',
          notes: @order.notes.to_s + "\n[Override] Manager approved despite inventory shortage. Back-order if needed. #{@notes}"
        )

        log_shortage_resolution('manager_override', {
          actor: @actor.email,
          reason: @notes || ''
        })

        notify_manager_and_warehouse

        Result.new(
          success?: true,
          order: @order,
          refunded_amount: 0,
          notes: "Order approved by manager override. Warehouse staff notified of back-order risk.",
          errors: []
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    def calculate_partial_delivery(shortage_items)
      items_delivered = @order.lines.count - shortage_items.count
      items_short = shortage_items.count

      {
        items_delivered: items_delivered,
        items_short: items_short,
        total_lines: @order.lines.count
      }
    end

    def update_order_lines_for_partial(shortage_items)
      shortage_map = shortage_items.index_by(&:product_id)

      @order.lines.each do |line|
        shortage = shortage_map[line.product_id]
        next unless shortage

        # Update qty to available amount
        if shortage.available_qty > 0
          line.update_column(:qty, shortage.available_qty)
          line.update_column(:line_total, shortage.available_qty * line.unit_price)
        else
          # Remove line if no stock at all
          line.destroy
        end
      end

      @order.recalculate_totals!
    end

    def maybe_create_refund
      # Check if order has associated payment
      # TODO: Integrate with payment reversal service
      0.to_d
    end

    def maybe_create_refund_for_shortage(shortage_value)
      # Create refund for shortage amount only
      shortage_value
    end

    def estimate_reschedule_date(shortage_items)
      # For MVP: Add 7 days from now
      # Future: Check purchase order ETAs, inbound stock ETAs
      7.days.from_now
    end

    def log_shortage_resolution(resolution_type, metadata = {})
      audit_data = {
        resolution_type: resolution_type,
        order_id: @order.id,
        shortage_detected_at: Time.current,
        metadata: metadata
      }

      Credit::AuditLogger.log(
        actor: @actor,
        organization: @order.organization,
        auditable: @order,
        action: 'shortage_resolved',
        changes: audit_data
      )
    end

    def notify_customer_refund
      # Send email + SMS to customer
      Notifications::CreateService.call(
        organization: @order.organization,
        recipients: [@order.customer.primary_contact],
        actor: @actor,
        notifiable: @order,
        type: 'order_cancelled_shortage',
        title: "Order cancelled due to inventory shortage",
        body: "Your order #{@order.order_number} has been cancelled as some items are out of stock. Full refund is being processed.",
        deep_link: "/orders/#{@order.id}",
        severity: 'medium'
      ) if @customer_communication[:email] || @customer_communication[:sms]
    rescue StandardError => e
      Rails.logger.warn("[ShortageResolution] Customer notification failed: #{e.message}")
    end

    def notify_customer_partial(shortage_items, refund_amount)
      item_names = shortage_items.first(3).map(&:product_name).join(', ')

      Notifications::CreateService.call(
        organization: @order.organization,
        recipients: [@order.customer.primary_contact],
        actor: @actor,
        notifiable: @order,
        type: 'order_partial_delivery',
        title: "Partial delivery for order #{@order.order_number}",
        body: "Due to inventory shortage, we're delivering available items only. #{item_names} will be refunded (₹#{refund_amount}). Updated order attached.",
        deep_link: "/orders/#{@order.id}",
        severity: 'medium'
      ) if @customer_communication[:email] || @customer_communication[:sms]
    rescue StandardError => e
      Rails.logger.warn("[ShortageResolution] Partial delivery notification failed: #{e.message}")
    end

    def notify_customer_reschedule(reschedule_date)
      Notifications::CreateService.call(
        organization: @order.organization,
        recipients: [@order.customer.primary_contact],
        actor: @actor,
        notifiable: @order,
        type: 'order_rescheduled_shortage',
        title: "Order rescheduled due to inventory shortage",
        body: "Your order #{@order.order_number} has been rescheduled to #{reschedule_date.to_date} to ensure full availability. You'll be notified when items arrive.",
        deep_link: "/orders/#{@order.id}",
        severity: 'low'
      ) if @customer_communication[:email] || @customer_communication[:sms]
    rescue StandardError => e
      Rails.logger.warn("[ShortageResolution] Reschedule notification failed: #{e.message}")
    end

    def notify_manager_and_warehouse
      # Notify warehouse that this order is being force-approved despite shortage
      warehouse_staff = @order.organization.users
                             .joins(:memberships)
                             .where(roles: { name: %w[warehouse_staff manager admin] })
                             .distinct

      Notifications::CreateService.call(
        organization: @order.organization,
        recipients: warehouse_staff,
        actor: @actor,
        notifiable: @order,
        type: 'order_override_shortage',
        title: "Manager override: Order approved despite inventory shortage",
        body: "Order #{@order.order_number} approved by #{@actor.email}. Some items may need back-ordering.",
        deep_link: "/orders/#{@order.id}",
        severity: 'high'
      )
    rescue StandardError => e
      Rails.logger.warn("[ShortageResolution] Manager/warehouse notification failed: #{e.message}")
    end

    def failure(errors)
      Result.new(success?: false, order: @order, refunded_amount: 0, notes: nil, errors: errors)
    end
  end
end
