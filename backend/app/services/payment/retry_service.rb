# frozen_string_literal: true

module Payments
  class RetryService
    def initialize(payment, initiator_type = 'customer')
      @payment = payment
      @initiator_type = initiator_type # 'customer' or 'system'
    end

    def call
      validate!
      attempt_retry
      success_response
    rescue ValidationError => error
      error_response(error.message)
    rescue StandardError => error
      error_response("Payment retry failed: #{error.message}")
    end

    private

    def validate!
      raise ValidationError, 'Payment not found' unless @payment.present?
      raise ValidationError, 'Payment is not in failed state' unless @payment.external_payment_status == 'failed'
      raise ValidationError, 'Maximum retry attempts exceeded' if @payment.retry_count >= 3
      raise ValidationError, 'Payment retry already scheduled' if @payment.retry_status == 'scheduled'
      raise ValidationError, 'This payment has already been successfully completed' if @payment.retry_status == 'completed'
      raise ValidationError, 'No invoice linked to this payment' if @payment.sales_invoices.empty?
    end

    def attempt_retry
      invoice = @payment.sales_invoices.first
      organization = invoice&.organization
      customer = invoice&.customer

      raise StandardError, 'Invoice not found' unless invoice
      raise StandardError, 'Organization not found' unless organization
      raise StandardError, 'Customer not found' unless customer

      # Initiate payment retry with Razorpay
      retry_response = initiate_razorpay_retry(invoice, organization)

      unless retry_response&.dig('success')
        raise StandardError, "Razorpay retry failed: #{retry_response&.dig('error')}"
      end

      # Update payment with retry details
      @payment.update(
        last_retry_at: Time.current,
        retry_count: @payment.retry_count + 1,
        retry_status: 'pending'
      )

      # Send confirmation email to customer if customer-initiated
      send_retry_confirmation(invoice, organization, customer) if @initiator_type == 'customer'
    end

    def initiate_razorpay_retry(invoice, organization)
      # Create a new payment link for the customer to retry
      # This is a simplified implementation - actual Razorpay API call would go here
      
      begin
        client = Razorpay::Client.new(
          key: ENV['RAZORPAY_KEY_ID'],
          secret: ENV['RAZORPAY_KEY_SECRET']
        )

        # Create new payment link since we don't have stored card details
        # In production, you might use token-based payments if available
        
        link_response = client.payment_link.create(
          upi_link: false,
          amount: (invoice.total_amount * 100).to_i,
          amount_paid: 0,
          currency: 'INR',
          accept_partial: false,
          first_min_partial_amount: nil,
          reference_id: "INV-#{invoice.invoice_number}-RETRY-#{Time.current.to_i}",
          description: "Retry Payment - Invoice #{invoice.invoice_number}",
          customer_notify: 0, # We'll notify via email
          notify: {
            sms: false,
            email: false
          },
          reminder_enable: false,
          notes: {
            invoice_id: invoice.id,
            customer_id: invoice.customer_id,
            organization_id: organization.id,
            retry_attempt: @payment.retry_count + 1,
            original_payment_id: @payment.external_payment_id
          },
          callback_url: "#{ENV['BACKEND_URL']}/api/v1/payments/razorpay/callback",
          callback_method: 'get'
        )

        # Store the new payment link for the customer
        current_payload = @payment.external_payload_data || {}
        @payment.update(
          external_payload_data: {
            **current_payload,
            retry_link: link_response['short_url'],
            retry_link_created_at: Time.current.iso8601
          }
        )

        { success: true, payment_link: link_response['short_url'] }
      rescue => error
        Rails.logger.error({
          service: 'Payments::RetryService',
          action: 'initiate_razorpay_retry',
          payment_id: @payment.id,
          error: error.message
        }.to_json)

        { success: false, error: error.message }
      end
    end

    def send_retry_confirmation(invoice, organization, customer)
      # Send email confirming the retry was initiated
      PaymentRetryMailer.with(
        payment: @payment,
        organization: organization,
        customer: customer,
        invoice: invoice
      ).payment_failed_notification.deliver_later
    rescue => error
      Rails.logger.error({
        service: 'Payments::RetryService',
        action: 'send_retry_confirmation',
        error: error.message
      }.to_json)
    end

    def success_response
      {
        success: true,
        message: "Payment retry initiated. Retry attempt ##{@payment.retry_count}",
        payment: {
          id: @payment.id,
          external_payment_id: @payment.external_payment_id,
          retry_count: @payment.retry_count,
          retry_status: @payment.retry_status,
          next_retry_at: @payment.next_retry_at,
          last_retry_at: @payment.last_retry_at
        },
        next_action: 'Please check your email for payment instructions'
      }
    end

    def error_response(message)
      {
        success: false,
        message: message,
        error: message
      }
    end

    class ValidationError < StandardError; end
  end
end
