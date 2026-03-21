module Payments
  # Feature 11: Automatically deducts available advance balance from new payments
  #
  # When a customer makes a new payment, this service:
  # 1. Checks available advance balance
  # 2. Auto-deducts advance to cover part of outstanding invoices
  # 3. Applies remaining cash payment to newer invoices
  #
  # Example:
  #   Customer has:
  #     - Advance balance: ₹200
  #     - Invoice 1 (oldest): ₹500 outstanding
  #     - Invoice 2 (newest): ₹300 outstanding
  #     - Makes payment: ₹400
  #
  #   Auto-deduction flow:
  #   1. Apply ₹200 advance → Invoice 1 (now ₹300 outstanding)
  #   2. Apply ₹400 cash → Invoice 1 & 2 via FIFO
  #   3. Result: All invoices paid, no new advance created
  #
  # Usage:
  #   result = Payments::AdvanceDeductionService.call(
  #     customer:     customer,
  #     payment_amount: 400.0,
  #     organization: org
  #   )
  #   result.advance_deducted # => 200.0
  #   result.remaining_payment # => 400.0
  #   result.advance_used # => AdvancePayment
  #
  class AdvanceDeductionService
    Result = Struct.new(:advance_deducted, :remaining_payment, :advance_used, :errors,
                        keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    # @param customer         [Customer]
    # @param payment_amount   [Numeric] gross payment amount
    # @param organization    [Organization]
    def initialize(customer:, payment_amount:, organization:)
      @customer         = customer
      @payment_amount   = payment_amount.to_d
      @organization     = organization
      @errors           = []
    end

    def call
      # Find applicable advance payments (unapplied or partially applied)
      applicable_advances = @customer.advance_payments
                                    .for_org(@organization)
                                    .unapplied
                                    .order(:created_at) # FIFO

      return Result.new(
        advance_deducted: 0,
        remaining_payment: @payment_amount,
        advance_used: nil,
        errors: []
      ) if applicable_advances.empty?

      total_deducted = 0.to_d
      advance_used = nil

      applicable_advances.each do |advance|
        break if total_deducted >= @payment_amount

        # How much can we deduct from this advance?
        deductible = [advance.balance.to_d, @payment_amount - total_deducted].min

        if deductible > 0
          advance_used = advance
          total_deducted += deductible
        end
      end

      Result.new(
        advance_deducted: total_deducted.round(2),
        remaining_payment: (@payment_amount - total_deducted).round(2),
        advance_used: advance_used,
        errors: []
      )
    end

    private

    def failure(errors)
      Result.new(
        advance_deducted: 0,
        remaining_payment: @payment_amount,
        advance_used: nil,
        errors: errors
      )
    end
  end
end
