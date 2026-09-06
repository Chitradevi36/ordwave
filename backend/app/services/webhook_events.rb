# frozen_string_literal: true

# Fires webhook delivery for known business events.
# Call from service objects AFTER the main transaction commits.
#
# Usage (fire-and-forget; logs but never raises):
#   WebhookEvents.fire(
#     organization: org,
#     event:        'order.approved',
#     payload:      { id: order.id, order_number: order.order_number, ... }
#   )
#
module WebhookEvents
  module_function

  EVENT_MAP = {
    # Orders
    'order.created'           => :serialize_order,
    'order.approved'          => :serialize_order,
    'order.delivered'         => :serialize_order,
    # Finance
    'invoice.generated'       => :serialize_invoice,
    'payment.received'        => :serialize_payment,
    # Inventory
    'inventory.low_stock'     => :serialize_low_stock,
    # Customers
    'customer.credit_blocked' => :serialize_customer,
  }.freeze

  def fire(organization:, event:, payload:)
    raise ArgumentError, "Unknown webhook event: #{event}" unless EVENT_MAP.key?(event)

    WebhookEndpoint.deliver_event(
      organization: organization,
      event:        event,
      payload:      payload.merge(event: event, timestamp: Time.current.iso8601)
    )
  rescue StandardError => e
    Rails.logger.warn("[WebhookEvents] Failed to fire #{event}: #{e.message}")
  end

  # ── Payload builders ──────────────────────────────────────────────────────

  def order_payload(order)
    {
      id:           order.id,
      order_number: order.order_number,
      status:       order.status,
      total_amount: order.total_amount.to_f,
      customer: {
        id:   order.customer_id,
        name: order.customer&.name
      },
      organization_id: order.organization_id,
      branch_id:       order.branch_id,
      created_at:      order.created_at&.iso8601,
      updated_at:      order.updated_at&.iso8601
    }
  end

  def invoice_payload(invoice)
    {
      id:             invoice.id,
      invoice_number: invoice.invoice_number,
      status:         invoice.status,
      grand_total:    invoice.grand_total.to_f,
      customer: {
        id:   invoice.respond_to?(:customer_id) ? invoice.customer_id : nil,
        name: invoice.respond_to?(:customer)   ? invoice.customer&.name : nil
      },
      organization_id: invoice.organization_id,
      created_at:      invoice.created_at&.iso8601
    }
  end

  def payment_payload(payment)
    {
      id:              payment.id,
      amount:          payment.amount.to_f,
      payment_method:  payment.payment_mode,
      status:          payment.status,
      organization_id: payment.organization_id,
      created_at:      payment.created_at&.iso8601
    }
  end

  def low_stock_payload(product:, inventory_level:, threshold:)
    {
      product_id:      product.id,
      product_name:    product.name,
      product_sku:     product.sku,
      on_hand:         inventory_level.on_hand.to_f,
      threshold:       threshold.to_f,
      branch_id:       inventory_level.branch_id,
      organization_id: inventory_level.organization_id
    }
  end

  def customer_payload(customer)
    {
      id:              customer.id,
      name:            customer.name,
      organization_id: customer.organization_id,
      credit_status:   customer.credit_account&.credit_status
    }
  end
end
