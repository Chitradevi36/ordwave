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
