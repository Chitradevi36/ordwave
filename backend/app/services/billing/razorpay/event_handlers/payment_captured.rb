# frozen_string_literal: true

module Billing
  module Razorpay
    module EventHandlers
      # Handles `payment.captured` and `payment.authorized` events
      # Updates invoice payment status and cascades to order
      class PaymentCaptured
        def initialize(organization:, subscription:, payload:)
          @organization = organization
          @subscription = subscription
          @payload = payload
        end

        def call
          payment_data = @payload.dig('payload', 'payment', 'entity') || {}
          invoice_order_id = extract_order_reference(payment_data)

          unless invoice_order_id.present?
            Rails.logger.warn("[PaymentCaptured] No order/invoice reference in payment #{payment_data['id']}")
            return
          end

          # Find the order by notes/reference
          order = @organization.sales_orders.find_by(id: invoice_order_id) ||
                  @organization.sales_orders.find_by(order_number: invoice_order_id)

          unless order.present?
            Rails.logger.warn("[PaymentCaptured]Order #{invoice_order_id} not found for org #{@organization.id}")
            return
          end

          # Create/update Payment record
          payment = Payment.from_razorpay_webhook(
            payment_data,
            @organization,
            invoice: order.invoices.last  # Link to most recent invoice
          )

          # Auto-confirm the payment as it's from external system
          payment.confirm_external_payment!

          # Sync status to invoices (will update invoice.paid_at and invoice.status)
          payment.sync_to_invoices!

          # Notify customer
          notify_payment_received(order, payment)
        end

        private

        def extract_order_reference(payment_data)
          # Try to find order ID in various places:
          # 1. notes field (custom metadata)
          # 2. description field
          # 3. customer email → find customer → get order
          notes = payment_data.dig('notes') || {}
          notes['order_id'] || notes['sales_order_id'] ||
            payment_data.dig('description')&.match(/ORDER[#:]?(\d+)/)&.[](1)
        end

        def notify_payment_received(order, payment)
          org = @organization

          begin
            # Create notification for order creator
            owner = order.created_by
            Notifications::CreateService.call(
              organization: org,
              recipients: [owner].compact,
              actor: nil,
              notifiable: order,
              type: 'payment_received',
              title: "Payment Received — Order #{order.order_number}",
              body: "Invoice payment of ₹#{payment.amount} received for #{order.customer&.name}",
              deep_link: "/orders/#{order.id}",
              severity: 'medium'
            )
          rescue StandardError => e
            Rails.logger.error("[PaymentCaptured] Notification failed: #{e.message}")
          end
        end
      end
    end
  end
end
