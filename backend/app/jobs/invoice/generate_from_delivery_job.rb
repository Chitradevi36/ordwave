module Invoice
  # Asynchronously generates a SalesInvoice from a completed TripStop.
  #
  # Triggered by Delivery::CompleteStopService when
  #   organization.settings['auto_invoice_trigger'] == 'on_delivery'
  #
  # Idempotent: if an invoice already exists for this stop + customer pair
  # (checked inside GenerateFromDeliveryService), the job silently no-ops.
  #
  class GenerateFromDeliveryJob < ApplicationJob
    queue_as :invoicing

    # Retry up to 5 times with exponential back-off before discarding
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveRecord::RecordNotFound

    # @param stop_id [Integer] TripStop id
    def perform(stop_id)
      stop = TripStop.find(stop_id)
      return unless stop.delivered? || stop.partial_delivery?

      order  = stop.sales_order
      branch = order.branch

      # Build delivered_lines from sales_order_lines.delivered_qty
      delivered_lines = order.lines.map do |sol|
        invoiceable_qty = sol.delivered_qty.to_d - sol.invoiced_qty.to_d
        next if invoiceable_qty <= 0

        {
          product_id:          sol.product_id,
          qty:                 invoiceable_qty,
          sales_order_line_id: sol.id,
          unit_price:          sol.unit_price,
          discount_pct:        sol.discount_pct,
          hsn_code:            sol.hsn_code,
          gst_rate:            sol.gst_rate
        }
      end.compact

      return if delivered_lines.empty?

      # Uses a system-level actor if no human actor is available
      actor = stop.delivery_trip.driver || order.created_by

      result = Invoice::GenerateFromDeliveryService.call(
        actor:             actor,
        branch:            branch,
        customer:          order.customer,
        sales_order:       order,
        trip_stop:         stop,
        invoice_date:      stop.delivered_at&.to_date || Date.current,
        generation_source: 'auto_on_delivery',
        delivered_lines:   delivered_lines
      )

      if result.success?
        Rails.logger.info("[Invoice::GenerateFromDeliveryJob] Invoice #{result.invoice.invoice_number} created for stop #{stop_id}")
      else
        Rails.logger.error("[Invoice::GenerateFromDeliveryJob] Failed for stop #{stop_id}: #{result.errors.join(', ')}")
        # Re-raise so retry logic kicks in (unless it's an idempotency error)
        unless result.errors.any? { |e| e.include?('already auto-generated') }
          raise "Invoice generation failed: #{result.errors.join(', ')}"
        end
      end
    end
  end
end
