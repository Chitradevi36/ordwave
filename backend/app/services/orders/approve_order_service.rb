module Orders
  # Approves or rejects an on_hold or submitted order.
  #
  # Usage:
  #   result = Orders::ApproveOrderService.call(
  #     actor:    current_user,
  #     order:    sales_order,
  #     decision: 'approved' | 'rejected',
  #     reason:   "string"     # required for rejected
  #   )
  #
  class ApproveOrderService
    VALID_DECISIONS = %w[approved rejected].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, decision:, reason: nil)
      @actor    = actor
      @order    = order
      @decision = decision.to_s
      @reason   = reason
    end

    def call
      errors = validate
      return { ok: false, order: @order, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        @order.transition_to!(@decision, reason: @reason)

        action = @decision == 'approved' ? 'order_approved' : 'order_rejected'
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       action,
          changes:      { status: @decision },
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
      errs << "Invalid decision. Must be 'approved' or 'rejected'" unless VALID_DECISIONS.include?(@decision)
      errs << 'Order must be submitted or on_hold to approve or reject' unless @order.on_hold? || @order.submitted?
      errs << 'Reason is required when rejecting' if @decision == 'rejected' && @reason.blank?
      errs
    end
  end
end
