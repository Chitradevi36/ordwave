module Payments
  # Reverses a confirmed payment: un-allocates all invoice amounts,
  # restores outstanding balances, marks payment reversed, re-syncs credit.
  #
  # Usage:
  #   result = Payments::ReversePaymentService.call(
  #     actor:   current_user,
  #     payment: payment,
  #     reason:  'Cheque bounced'
  #   )
  class ReversePaymentService
    Result = Struct.new(:success?, :payment, :errors, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    def initialize(actor:, payment:, reason:)
      @actor   = actor
      @payment = payment
      @reason  = reason
      @errors  = []
    end

    def call
      return failure(['Payment is not confirmed']) unless @payment.confirmed?
      return failure(['Reversal reason is required']) if @reason.blank?

      ActiveRecord::Base.transaction do
        reverse_allocations
        reverse_advance_payments
        mark_payment_reversed
        Payments::CreditSyncService.call(
          customer:     @payment.customer,
          organization: @payment.organization
        )
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @payment.organization,
          auditable:    @payment,
          action:       'payment_reversed',
          changes:      { reason: @reason, amount: @payment.amount },
          reason:       @reason
        )
      end

      Result.new(success?: true, payment: @payment.reload, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    private

    def reverse_allocations
      @payment.allocations.active.each do |alloc|
        invoice = alloc.sales_invoice

        new_paid        = (invoice.paid_amount.to_d - alloc.allocated_amount.to_d).round(2)
        new_outstanding = (invoice.outstanding_amount.to_d + alloc.allocated_amount.to_d).round(2)

        # Restore status: if outstanding > 0, it's back to issued
        restored_status = new_outstanding >= invoice.grand_total ? 'issued' : 'partially_paid'

        invoice.update_columns(
          paid_amount:        [new_paid, 0].max,
          outstanding_amount: [new_outstanding, invoice.grand_total.to_d].min,
          status:             restored_status
        )

        alloc.update!(status: 'reversed', reversed_at: Time.current)

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @payment.organization,
          auditable:    invoice,
          action:       'payment_allocation_reversed',
          changes:      {
            payment_id:        @payment.id,
            reversed_amount:   alloc.allocated_amount,
            outstanding_after: invoice.outstanding_amount
          },
          reason: @reason
        )
      end
    end

    def reverse_advance_payments
      @payment.advance_payments.where.not(status: 'refunded').each do |adv|
        # If the advance hasn't been applied yet or partially applied,
        # mark what can be reversed as refunded.
        adv.update!(status: 'refunded', refunded_at: Time.current,
                    notes: "Auto-refunded on payment reversal: #{@reason}")
      end
    end

    def mark_payment_reversed
      @payment.update!(
        status:             'reversed',
        reversed_at:        Time.current,
        reversal_reason:    @reason,
        allocated_amount:   0,
        unallocated_amount: 0
      )
    end

    def failure(errors)
      Result.new(success?: false, payment: @payment, errors: errors)
    end
  end
end
