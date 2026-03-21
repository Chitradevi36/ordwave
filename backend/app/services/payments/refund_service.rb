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
      # TODO: Implement Razorpay refund API call
      # 1. Call Razorpay refund endpoint with payment_id
      # 2. Create refund record in system
      # 3. Send customer notification
      # 4. Create audit log
      
      begin
        refund_amount = calculate_refund_amount

        # Placeholder: In production, call Razorpay API here
        # response = RazorpayClient.create_refund(
        #   payment_id: payment.external_payment_id,
        #   amount: (refund_amount * 100).to_i,
        #   notes: { reason: @reason, order_id: @order.id }
        # )

        success(
          refund_payment_id: "refund-#{Time.current.to_i}",
          refund_amount: refund_amount
        )
      rescue StandardError => error
        failure("Razorpay refund failed: #{error.message}")
      end
    end

    def refund_to_bank_account(payment)
      # TODO: Implement bank transfer refund
      # 1. Create reverse bank transfer record
      # 2. Queue for payment (daily batch at 6 PM)
      # 3. Mark as "refund_pending"
      # 4. Notify customer
      
      failure("Bank refunds still in development - notify customer manually")
    end

    def mark_cash_refund(payment)
      # Cash is physical, mark as "refund_pending"
      # Daily reconciliation will account for it
      
      failure("Cash refunds still in development - notify customer manually")
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
