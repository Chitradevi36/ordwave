module Orders
  # Manually places a submitted order on hold.
  # Only managers+ can do this; reason is required so there's an audit trail.
  #
  # Usage:
  #   result = Orders::HoldOrderService.call(
  #     actor:  current_user,
  #     order:  sales_order,
  #     reason: "Awaiting stock confirmation"
  #   )
  #
  class HoldOrderService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, reason: nil)
      @actor  = actor
      @order  = order
      @reason = reason
    end

    def call
      errors = validate
      return { ok: false, order: @order, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @order.transition_to!('on_hold', reason: @reason)

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       'order_on_hold',
          changes:      { status: 'on_hold' },
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
      errs << 'Order must be in submitted status to put on hold' unless @order.submitted?
      errs << 'Reason is required when placing an order on hold'  if @reason.blank?
      errs
    end
  end
end
