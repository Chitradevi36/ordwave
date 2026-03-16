# frozen_string_literal: true

module Payments
  # For failed Razorpay payments, generates an alternative payment link
  # Triggered by PaymentRetryJob after 3 failed retries
  #
  # Creates a fresh payment link (via Razorpay) and sends to customer
  # Increases chance of payment recovery vs. just giving up
  #
  # Usage:
  #   result = Payments::GenerateAltPaymentLinkService.call(
  #     payment: payment_obj,
  #     customer: customer_obj,
  #     invoice: invoice_obj,
  #     organization: org_obj
  #   )
  #   result.success? #=> true/false
  #   result.payment_link_url #=> "https://rzp.io/l/abc123"
  #
  class GenerateAltPaymentLinkService
    Result = Struct.new(:success?, :payment_link_url, :payment_link_id, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(payment:, customer:, invoice:, organization:)
      @payment = payment
      @customer = customer
      @invoice = invoice
      @organization = organization
      @errors = []
    end

    def call
      validate!
      return failure("Validation failed") if @errors.any?

      link_response = create_payment_link
      return failure(link_response[:error]) unless link_response.present?

      # Store link details in payment record
      update_payment_with_link(link_response)

      # Send notification to customer
      notify_customer(link_response[:short_url])

      success(link_response[:short_url], link_response[:id])
    rescue StandardError => error
      Rails.logger.error("[Payments::GenerateAltPaymentLinkService] Error: #{error.message}")
      failure("Failed to generate payment link: #{error.message}")
    end

    private

    def validate!
      @errors << 'Payment not found' if @payment.blank?
      @errors << 'Customer not found' if @customer.blank?
      @errors << 'Invoice not found' if @invoice.blank?
      @errors << 'Organization not found' if @organization.blank?
      @errors << 'Razorpay not configured' unless razorpay_configured?
    end

    def razorpay_configured?
      ENV['RAZORPAY_KEY_ID'].present? && ENV['RAZORPAY_KEY_SECRET'].present?
    end

    def create_payment_link
      begin
        client = Razorpay::Client.new(
          key: ENV['RAZORPAY_KEY_ID'],
          secret: ENV['RAZORPAY_KEY_SECRET']
        )

        amount_paise = (@invoice.total_amount * 100).to_i
        reference_id = "INV-#{@invoice.invoice_number}-RETRY-#{Time.current.to_i}"

        link_response = client.payment_link.create(
          amount: amount_paise,
          currency: 'INR',
          accept_partial: false,
          reference_id: reference_id,
          description: "Payment for Invoice #{@invoice.invoice_number}",
          customer_notify: 0, # We'll handle notification
          notify: {
            sms: false,
            email: false
          },
          notes: {
            invoice_id: @invoice.id,
            invoice_number: @invoice.invoice_number,
            customer_id: @customer.id,
            organization_id: @organization.id,
            retry_attempt: @payment.retry_count + 1,
            original_payment_id: @payment.external_payment_id,
            payment_type: 'alternative_link'
          },
          callback_url: "#{ENV['BACKEND_URL']}/api/v1/payments/razorpay/callback",
          callback_method: 'get'
        )

        {
          id: link_response['id'],
          short_url: link_response['short_url'],
          user_id: link_response['user_id'],
          created_at: link_response['created_at']
        }
      rescue Razorpay::ApiError => error
        {
          error: "Razorpay API error: #{error.message}"
        }
      end
    end

    def update_payment_with_link(link_response)
      current_payload = @payment.external_payload_data || {}

      @payment.update(
        external_payload_data: current_payload.merge({
          'alt_payment_link_id' => link_response[:id],
          'alt_payment_link_url' => link_response[:short_url],
          'alt_link_created_at' => Time.current.iso8601,
          'alt_link_attempt_number' => @payment.retry_count + 1
        }),
        retry_status: 'pending' # Reset to pending for new link
      )

      Rails.logger.info(
        "[Payments::GenerateAltPaymentLinkService] " \
        "Payment #{@payment.id} linked to alt payment #{link_response[:id]}"
      )
    end

    def notify_customer(payment_link_url)
      # Send SMS if configured
      if TwilioClient.enabled? && @customer.phone.present?
        send_sms_notification(payment_link_url)
      end

      # Send email
      if @customer.email.present?
        send_email_notification(payment_link_url)
      end

      # Create in-app notification for customer contact
      if @invoice.customer_contact&.user.present?
        Notification.create(
          user: @invoice.customer_contact.user,
          organization: @organization,
          title: 'Payment Link Ready',
          body: "Your invoice #{@invoice.invoice_number} payment link is ready. Click to pay.",
          notification_type: 'payment_link',
          deep_link_url: payment_link_url
        )
      end
    rescue => error
      Rails.logger.warn(
        "[Payments::GenerateAltPaymentLinkService] " \
        "Failed to notify customer: #{error.message}"
      )
      # Don't fail the service just because notification failed
    end

    def send_sms_notification(payment_link_url)
      message = "Hi #{@customer.name}, your invoice #{@invoice.invoice_number} " \
                "for ₹#{@invoice.total_amount.round(0)} is due. Pay here: #{payment_link_url}"

      # Truncate if over SMS limit
      if message.length > 160
        message = "Invoice #{@invoice.invoice_number}: ₹#{@invoice.total_amount.round(0)} due. " \
                  "Pay: #{payment_link_url}"
      end

      result = TwilioClient.send_sms(
        phone_number: @customer.phone,
        message: message
      )

      unless result[:success]
        Rails.logger.warn(
          "[Payments::GenerateAltPaymentLinkService] " \
          "SMS failed for #{@customer.id}: #{result[:error]}"
        )
      end
    end

    def send_email_notification(payment_link_url)
      PaymentMailer.alt_payment_link(
        invoice: @invoice,
        customer: @customer,
        payment_link_url: payment_link_url
      ).deliver_later
    end

    def success(link_url, link_id)
      Result.new(
        success?: true,
        payment_link_url: link_url,
        payment_link_id: link_id,
        errors: []
      )
    end

    def failure(message)
      Result.new(
        success?: false,
        payment_link_url: nil,
        payment_link_id: nil,
        errors: [@errors, message].flatten.compact
      )
    end
  end
end
