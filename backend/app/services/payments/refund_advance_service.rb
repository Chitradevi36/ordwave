module Payments
  # Refunds an advance payment (marks it as refunded, zeroes balance).
  #
  # Usage:
  #   result = Payments::RefundAdvanceService.call(
  #     actor:           current_user,
  #     advance_payment: advance,
  #     reason:          'Customer requested refund'
  #   )
  class RefundAdvanceService
    Result = Struct.new(:success?, :advance_payment, :errors, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    def initialize(actor:, advance_payment:, reason: nil)
      @actor   = actor
      @advance = advance_payment
      @reason  = reason
      @errors  = []
    end

    def call
      return failure(['Advance is not refundable']) unless @advance.refundable?

      ActiveRecord::Base.transaction do
        refunded_balance = @advance.balance.to_d

        # Reduce source payment unallocated
        src = @advance.source_payment
        src.update_columns(
          unallocated_amount: [src.unallocated_amount.to_d - refunded_balance, 0].max.round(2)
        )

        @advance.update!(
          balance:      0,
          status:       'refunded',
          refunded_at:  Time.current,
          notes:        @reason.presence || 'Refunded'
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @advance.organization,
          auditable:    @advance,
          action:       'advance_payment_refunded',
          changes:      { refunded_amount: refunded_balance, reason: @reason }
        )
      end

      Result.new(success?: true, advance_payment: @advance.reload, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    private

    def failure(errors)
      Result.new(success?: false, advance_payment: @advance, errors: errors)
    end
  end
end
