module Invoice
  # Asynchronously generates a SalesInvoice from a completed TripStop.
  #
  # Triggered by Delivery::CompleteStopService when
  #   organization.settings['auto_invoice_trigger'] == 'on_delivery'
  #
  # Idempotent: if an invoice already exists for this stop + customer pair
  # (checked inside GenerateFromDeliveryService), the job silently no-ops.
  #
  # Error handling:
  #   - Retries up to 5 times before giving up
  #   - On persistent failure (dead-letter), alerts organization managers
  #   - Logs all failures with full context for debugging
  #
  class GenerateFromDeliveryJob < ApplicationJob
    queue_as :invoicing

    # Retry up to 5 times with exponential back-off before discarding
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveRecord::RecordNotFound

    # On permanent failure (after max retries), quarantine + alert the organization
    discard_on StandardError do |job, exception|
      stop = TripStop.find_by(id: job.arguments.first)
      quarantine_and_alert(stop, exception) if stop.present?
    end

    # @param stop_id [Integer] TripStop id
    def perform(stop_id)
      stop = TripStop.find(stop_id)
      return unless stop.delivered? || stop.partial_delivery?

      order  = stop.sales_order
      branch = order.branch

      # Build delivered_lines from sales_order_lines.
      # If delivered_qty was never stamped (driver marked stop delivered without
      # per-line data), fall back to the ordered qty for fully-delivered stops.
      delivered_lines = order.lines.map do |sol|
        effective_delivered = sol.delivered_qty.to_d
        # Fallback: treat ordered qty as delivered when stop is fully delivered
        # and the line never received an explicit delivered_qty
        if effective_delivered.zero? && stop.delivered?
          effective_delivered = sol.qty.to_d
        end

        invoiceable_qty = effective_delivered - sol.invoiced_qty.to_d
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

    private

    # ── Error Handling ──────────────────────────────────────────────────────

    # Called when job is permanently discarded after max retries
    # Quarantines the invoice generation for manual review + one-click retry
    def self.quarantine_and_alert(stop, exception)
      org = stop.delivery_trip.organization
      order = stop.sales_order

      # Create quarantine record for the failed invoice generation
      begin
        quarantine = InvoiceGenerationQuarantine.create!(
          organization: org,
          trip_stop: stop,
          sales_order: order,
          branch: order.branch,
          error_message: exception.message,
          error_backtrace: exception.backtrace&.first(5)&.join("\n"),
          delivered_lines: stop.delivered_lines_snapshot || {},
          error_context: {
            retry_count_before_discard: 5,
            last_error_at: Time.current.iso8601
          }
        )

        Rails.logger.error("[Invoice::GenerateFromDeliveryJob] Quarantine created: #{quarantine.id} for stop #{stop.id}")
      rescue StandardError => e
        Rails.logger.error("[Invoice::GenerateFromDeliveryJob] Failed to create quarantine: #{e.message}")
      end

      # Call original alert method for backward compatibility + notifications
      alert_persistent_failure(stop, exception)
    end

    # Called when job is permanently discarded after max retries
    # Creates an alert notification for organization managers
    def self.alert_persistent_failure(stop, exception)
      org = stop.delivery_trip.organization
      order = stop.sales_order

      # Log to Sentry or error tracking service if available
      if defined?(Sentry)
        Sentry.capture_exception(exception,
          extra: {
            trip_stop_id: stop.id,
            sales_order_id: order.id,
            order_number: order.order_number,
            customer: order.customer&.name,
            delivery_date: stop.delivered_at
          }
        )
      end

      # Create alert notification for managers and admins
      begin
        managers = User.joins(:memberships)
                       .where(memberships: { organization_id: org.id, deleted_at: nil, active: true })
                       .joins(memberships: :role)
                       .where(roles: { name: %w[manager admin owner] })
                       .distinct

        Notifications::CreateService.call(
          organization: org,
          recipients:   managers,
          actor:        nil,
          notifiable:   order,
          type:         'invoice_generation_failed',
          title:        "⚠️ Auto-Invoice Failed — Order #{order.order_number}",
          body:         "Invoice generation failed after 5 retries for delivery of #{order.customer&.name}. Review in quarantine queue.",
          deep_link:    "/invoices/quarantine",
          severity:     'high'
        )

        Rails.logger.error("[Invoice::GenerateFromDeliveryJob] Persistent failure alert sent for stop #{stop.id}: #{exception.message}")
      rescue StandardError => e
        Rails.logger.error("[Invoice::GenerateFromDeliveryJob] Failed to create alert notification: #{e.message}")
      end
    end
  end
end
