module Orders
  # Cancels an order. Approved orders may only be cancelled by owners/admins.
  # Reason is always required.
  #
  # Usage:
  #   result = Orders::CancelOrderService.call(
  #     actor:  current_user,
  #     order:  sales_order,
  #     reason: "Customer withdrew"
  #   )
  #
  class CancelOrderService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, reason:)
      @actor  = actor
      @order  = order
      @reason = reason
    end

    def call
      errors = validate
      return { ok: false, order: @order, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @order.transition_to!('cancelled', reason: @reason)

        # Release any inventory reservations held for this order
        unreserve_result = Inventory::UnreserveForOrder.call(
          sales_order: @order,
          actor:       @actor,
          reason:      @reason
        )
        unless unreserve_result.success?
          Rails.logger.warn("[CancelOrderService] Unreservation failed for order #{@order.id}: #{unreserve_result.errors.join(', ')}")
        end

        # Reset pick_status so warehouse staff don't act on a cancelled order
        if @order.class.column_names.include?('pick_status')
          @order.update_columns(pick_status: 0, picked_by_id: nil, picked_at: nil,
                                pick_confirmed_by_id: nil, pick_confirmed_at: nil)
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       'order_cancelled',
          changes:      { status: 'cancelled' },
          reason:       @reason
        )

        { ok: true, order: @order.reload, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end

    private

    def validate
      errs = []
      errs << 'Reason is required to cancel an order' if @reason.blank?
      errs << 'Order cannot be cancelled in its current state' unless @order.cancellable?
      errs
    end
  end
end
