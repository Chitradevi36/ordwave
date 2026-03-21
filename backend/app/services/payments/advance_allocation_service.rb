module Payments
  # Feature 11: Applies available advance balance to invoices during payment confirmation
  #
  # This service is called during payment confirmation to:
  # 1. Temporarily reduce outstanding amounts using advances
  # 2. Then allocate cash payment (both advance-covered and new cash)
  # 3. Finally confirm advance balance reductions
  #
  # Called by: ConfirmPaymentService after manual/FIFO allocation
  #
  # Usage:
  #   result = Payments::AdvanceAllocationService.call(
  #     actor:                current_user,
  #     customer:             customer,
  #     deduction_amount:     200.0,
  #     advance_payment:      advance
  #   )
  #
  class AdvanceAllocationService
    Result = Struct.new(:success?, :allocations, :advance_payment, :errors, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    # @param actor            [User] person performing allocation
    # @param customer         [Customer]
    # @param deduction_amount [Numeric] amount to deduct from advance
    # @param advance_payment  [AdvancePayment]
    def initialize(actor:, customer:, deduction_amount:, advance_payment:)
      @actor             = actor
      @customer          = customer
      @deduction_amount  = deduction_amount.to_d
      @advance_payment   = advance_payment
      @allocations       = []
      @errors            = []
    end

    def call
      return failure(['Advance payment not found']) if @advance_payment.blank?
      return failure(['Amount must be positive']) unless @deduction_amount > 0
      return failure(['Amount exceeds advance balance']) if @deduction_amount > @advance_payment.balance.to_d

      ActiveRecord::Base.transaction do
        # Find outstanding invoices to apply advance against (oldest first)
        outstanding_invoices = @customer.sales_invoices
                                       .where(status: %w[issued partially_paid])
                                       .where('outstanding_amount > 0')
                                       .order(:invoice_date, :created_at)

        remaining_deduction = @deduction_amount

        outstanding_invoices.each do |invoice|
          break if remaining_deduction <= 0

          # How much of this invoice can the advance cover?
          deductible = [invoice.outstanding_amount.to_d, remaining_deduction].min
          next if deductible <= 0

          # Create allocation from source payment (linked to advance)
          allocation = PaymentAllocation.create!(
            payment:          @advance_payment.source_payment,
            sales_invoice:    invoice,
            allocated_amount: deductible,
            status:           'active'
          )
          @allocations << allocation

          # Update invoice
          new_paid = (invoice.paid_amount.to_d + deductible).round(2)
          new_outstanding = (invoice.outstanding_amount.to_d - deductible).round(2)
          new_status = new_outstanding <= 0 ? 'paid' : 'partially_paid'

          invoice.update_columns(
            paid_amount:        new_paid,
            outstanding_amount: [new_outstanding, 0].max,
            status:             new_status
          )

          # Update source payment totals
          src = @advance_payment.source_payment
          src.update_columns(
            allocated_amount:   (src.allocated_amount.to_d + deductible).round(2),
            unallocated_amount: [src.unallocated_amount.to_d - deductible, 0].max.round(2)
          )

          # Update advance balance
          new_balance = (@advance_payment.balance.to_d - deductible).round(2)
          @advance_payment.update!(balance: new_balance)
          @advance_payment.sync_status!

          # Audit log
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @customer.organization,
            auditable:    @advance_payment,
            action:       'advance_auto_applied_to_invoice',
            changes:      {
              invoice_id:         invoice.id,
              invoice_number:     invoice.invoice_number,
              deducted_amount:    deductible,
              advance_balance_after: new_balance,
              source_payment_id:  @advance_payment.source_payment_id
            }
          )

          remaining_deduction -= deductible
        end

        # Sync credit account
        Payments::CreditSyncService.call(
          customer:     @customer,
          organization: @customer.organization
        )

        Result.new(
          success?: true,
          allocations: @allocations,
          advance_payment: @advance_payment,
          errors: []
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    private

    def failure(errors)
      Result.new(success?: false, allocations: [], advance_payment: @advance_payment,
                 errors: errors)
    end
  end
end
