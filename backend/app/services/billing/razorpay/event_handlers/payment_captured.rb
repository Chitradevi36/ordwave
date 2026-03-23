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
            Rails.logger.info("[PaymentCaptured] No order reference in payment #{payment_data['id']}. This is likely a subscription payment, not a sales order payment. Skipping order linking.")
            # For subscription payments, we update subscription status in SubscriptionCharged handler instead
            return
          end

          # Find the order by id or order_number
          order = @organization.sales_orders.find_by(id: invoice_order_id) ||
                  @organization.sales_orders.find_by(order_number: invoice_order_id)

          unless order.present?
            Rails.logger.warn("[PaymentCaptured] Order #{invoice_order_id} not found for org #{@organization.id}")
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
          
          # Try notes first
          ref = notes['order_id'] || notes['sales_order_id']
          return ref.to_i if ref.present?
          
          # Try to extract from description (e.g. "ORDER#12345 - Invoice")
          desc = payment_data.dig('description')
          if desc.present?
            match = desc.match(/ORDER[#:]?(\d+)/)
            return match[1].to_i if match.present?
          end
          
          nil
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
