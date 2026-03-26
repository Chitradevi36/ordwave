# frozen_string_literal: true

module Payments
  # Processes refunds for failed deliveries or customer returns
  # Handles multiple payment methods: cash, bank transfer, Razorpay, etc.
  #
  # Usage:
  #   result = Payments::RefundService.call(
  #     order: order_obj,
  #     organization: org_obj,
  #     reason: 'Delivery failed after max attempts'
  #   )
  #   result.success? #=> true/false
  #   result.refund_payment_id #=> "payment-123"
  #
  class RefundService
    Result = Struct.new(:success?, :refund_payment_id, :refund_amount, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(order:, organization:, reason: nil, refund_lines: nil)
      @order = order
      @organization = organization
      @reason = reason
      @refund_lines = refund_lines || order.lines  # Which line items to refund (default all)
    end

    def call
      validate!
      return failure("Validation failed") if @errors.any?

      # Check how payment was collected
      original_payment = find_original_payment
      return failure("No payment found for order") unless original_payment

      # Process refund based on payment method
      case original_payment.payment_mode
      when 'razorpay'
        refund_razorpay_payment(original_payment)
      when 'bank_transfer', 'neft', 'rtgs'
        refund_to_bank_account(original_payment)
      when 'cash'
        mark_cash_refund(original_payment)
      else
        failure("Refund for #{original_payment.payment_mode} not yet supported")
      end
    rescue StandardError => error
      Rails.logger.error("[Payments::RefundService] Error: #{error.message}")
      failure("Refund failed: #{error.message}")
    end

    private

    def validate!
      @errors = []
      @errors << 'Order not found' if @order.blank?
      @errors << 'Organization not found' if @organization.blank?
    end

    def find_original_payment
      # Find the payment that was originally collected for this order
      # Usually the most recent confirmed payment to this order's customer
      @organization.payments
                   .where(customer_id: @order.customer_id)
                   .where(status: 'confirmed')
                   .order(received_date: :desc)
                   .first
    end

    def refund_razorpay_payment(payment)
      refund_amount = calculate_refund_amount

      unless payment.external_payment_id.present?
        return failure("No Razorpay payment_id recorded for payment #{payment.payment_number}")
      end

      begin
        # Call Razorpay Refund API
        razorpay_refund = ::Razorpay::Payment.new(payment.external_payment_id).create_refund(
          amount: (refund_amount * 100).to_i, # Razorpay expects paise
          notes:  {
            reason:         @reason,
            order_id:       @order.id,
            order_number:   @order.order_number,
            organization:   @organization.name,
            initiated_at:   Time.current.iso8601
          }
        )

        # Persist a refund payment record locally
        refund_payment = @organization.payments.create!(
          customer:              @order.customer,
          amount:                refund_amount,
          payment_mode:          'razorpay',
          status:                'confirmed',
          payment_type:          'refund',
          payment_number:        "RFD-#{Time.current.strftime('%Y%m%d%H%M%S')}",
          external_payment_id:   razorpay_refund.id,
          received_date:         Date.current,
          notes:                 "Razorpay refund for order #{@order.order_number}: #{@reason}"
        )

        # Recalculate credit after refund
        if @order.customer.credit_account
          RecalculateCreditAccountJob.perform_later(@order.customer.credit_account.id)
        end

        Rails.logger.info(
          "[Payments::RefundService] Razorpay refund #{razorpay_refund.id} " \
          "created for ₹#{refund_amount} on payment #{payment.payment_number}"
        )

        success(refund_payment_id: refund_payment.id, refund_amount: refund_amount)
      rescue ::Razorpay::Error => e
        Rails.logger.error("[Payments::RefundService] Razorpay API error: #{e.message}")
        failure("Razorpay refund failed: #{e.message}")
      end
    end

    def refund_to_bank_account(payment)
      refund_amount = calculate_refund_amount

      # Create a refund payment record marked as pending — finance team
      # processes bank transfers in a daily batch.
      refund_payment = @organization.payments.create!(
        customer:         @order.customer,
        amount:           refund_amount,
        payment_mode:     payment.payment_mode,
        status:           'refund_pending',
        payment_type:     'refund',
        payment_number:   "RFD-#{Time.current.strftime('%Y%m%d%H%M%S')}",
        received_date:    Date.current,
        notes:            "Bank transfer refund for order #{@order.order_number}: #{@reason}. " \
                          "Original payment: #{payment.payment_number}"
      )

      # Recalculate credit
      if @order.customer.credit_account
        RecalculateCreditAccountJob.perform_later(@order.customer.credit_account.id)
      end

      Rails.logger.info(
        "[Payments::RefundService] Bank refund record #{refund_payment.payment_number} " \
        "created for ₹#{refund_amount} (pending batch transfer)"
      )

      success(refund_payment_id: refund_payment.id, refund_amount: refund_amount)
    end

    def mark_cash_refund(payment)
      refund_amount = calculate_refund_amount

      refund_payment = @organization.payments.create!(
        customer:         @order.customer,
        amount:           refund_amount,
        payment_mode:     'cash',
        status:           'refund_pending',
        payment_type:     'refund',
        payment_number:   "RFD-#{Time.current.strftime('%Y%m%d%H%M%S')}",
        received_date:    Date.current,
        notes:            "Cash refund for order #{@order.order_number}: #{@reason}. " \
                          "To be reconciled during daily cash handover."
      )

      Rails.logger.info(
        "[Payments::RefundService] Cash refund record #{refund_payment.payment_number} " \
        "created for ₹#{refund_amount} (pending cash reconciliation)"
      )

      success(refund_payment_id: refund_payment.id, refund_amount: refund_amount)
    end

    def calculate_refund_amount
      # Sum up line items being refunded
      @refund_lines.sum { |line| line.total_amount }
    end

    def success(refund_payment_id:, refund_amount:)
      Result.new(
        success?: true,
        refund_payment_id: refund_payment_id,
        refund_amount: refund_amount,
        errors: []
      )
    end

    def failure(message)
      Result.new(
        success?: false,
        refund_payment_id: nil,
        refund_amount: 0,
        errors: [@errors, message].flatten.compact
      )
    end
  end
end
