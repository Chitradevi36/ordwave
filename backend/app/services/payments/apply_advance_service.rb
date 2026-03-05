module Payments
  # Applies an advance payment balance to a specific invoice.
  #
  # Usage:
  #   result = Payments::ApplyAdvanceService.call(
  #     actor:           current_user,
  #     advance_payment: advance,
  #     invoice:         sales_invoice,
  #     amount:          500.0
  #   )
  class ApplyAdvanceService
    Result = Struct.new(:success?, :allocation, :errors, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    def initialize(actor:, advance_payment:, invoice:, amount:)
      @actor          = actor
      @advance        = advance_payment
      @invoice        = invoice
      @amount         = amount.to_d
      @errors         = []
    end

    def call
      return failure(['Advance payment is not applicable']) unless @advance.applicable?
      return failure(['Amount must be positive']) unless @amount > 0
      return failure(['Amount exceeds advance balance']) if @amount > @advance.balance.to_d
      return failure(['Amount exceeds invoice outstanding']) if @amount > @invoice.outstanding_amount.to_d
      return failure(['Invoice is not outstanding']) unless @invoice.status.in?(%w[issued partially_paid])

      ActiveRecord::Base.transaction do
        # Create a synthetic allocation pointing at source payment
        alloc = PaymentAllocation.create!(
          payment:          @advance.source_payment,
          sales_invoice:    @invoice,
          allocated_amount: @amount,
          status:           'active'
        )

        new_balance = (@advance.balance.to_d - @amount).round(2)
        @advance.update!(balance: new_balance)
        @advance.sync_status!

        new_paid        = (@invoice.paid_amount.to_d + @amount).round(2)
        new_outstanding = (@invoice.outstanding_amount.to_d - @amount).round(2)

        @invoice.update_columns(
          paid_amount:        new_paid,
          outstanding_amount: [new_outstanding, 0].max,
          status:             new_outstanding <= 0 ? @invoice.status : 'partially_paid'
        )

        # Update source payment's allocated/unallocated columns
        src = @advance.source_payment
        src.update_columns(
          allocated_amount:   (src.allocated_amount.to_d + @amount).round(2),
          unallocated_amount: [src.unallocated_amount.to_d - @amount, 0].max.round(2)
        )

        Payments::CreditSyncService.call(
          customer:     @advance.customer,
          organization: @advance.organization
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @advance.organization,
          auditable:    @advance,
          action:       'advance_payment_applied',
          changes:      {
            invoice_id:        @invoice.id,
            invoice_number:    @invoice.invoice_number,
            applied_amount:    @amount,
            balance_after:     new_balance
          }
        )

        Result.new(success?: true, allocation: alloc, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    private

    def failure(errors)
      Result.new(success?: false, allocation: nil, errors: errors)
    end
  end
end
