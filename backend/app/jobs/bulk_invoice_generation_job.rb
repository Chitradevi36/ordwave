# frozen_string_literal: true

# Generates invoices for multiple orders in bulk.
#
# Usage:
#   BulkInvoiceGenerationJob.perform_later(
#     organization_id: org.id,
#     order_ids: [1, 2, 3, ...],
#     user_id: current_user.id,
#     session_id: "uuid"  # For tracking in UI via ActionCable
#   )
#
# Flow:
#   1. Creates BulkGeneration record to track progress
#   2. Processes each order sequentially
#   3. Broadcasts progress updates via ActionCable
#   4. Returns success/error breakdown
#
class BulkInvoiceGenerationJob < ApplicationJob
  queue_as :invoicing

  # Do NOT retry the entire job — each order is processed independently with
  # its own error handling inside the loop. Retrying the whole job risks
  # creating duplicate invoices for already-processed orders.
  discard_on StandardError

  def perform(organization_id:, order_ids:, user_id:, session_id:)
    org   = Organization.find(organization_id)
    user  = User.find(user_id)
    orders = org.sales_orders.where(id: order_ids).includes(:branch, :customer, :lines)

    # Create tracking record
    bulk_gen = BulkGeneration.create!(
      organization: org,
      user: user,
      session_id: session_id,
      total_count: orders.count,
      completed_count: 0,
      error_count: 0,
      errors: []
    )

    started_at = Time.current

    begin
      orders.each_with_index do |order, idx|
        begin
          # Skip if already invoiced
          if order.invoiced?
            broadcast_progress(bulk_gen, "Skipping order #{order.order_number} (already invoiced)")
            next
          end

          # Generate invoice
          result = Invoice::GenerateFromDeliveryService.call(
            actor:             user,
            branch:            order.branch,
            customer:          order.customer,
            sales_order:       order,
            invoice_date:      Date.current,
            generation_source: 'manual_bulk',
            delivered_lines:   build_delivered_lines(order)
          )

          if result.success?
            bulk_gen.update(completed_count: idx + 1)
            broadcast_progress(bulk_gen, "✓ Invoice #{result.invoice.invoice_number} created for order #{order.order_number}")
          else
            bulk_gen.update(error_count: bulk_gen.error_count + 1)
            error_msg = "Order #{order.order_number}: #{result.errors.join(', ')}"
            bulk_gen.update(errors: bulk_gen.errors.push(error_msg))
            broadcast_progress(bulk_gen, "✗ #{error_msg}")
          end
        rescue StandardError => e
          bulk_gen.update(error_count: bulk_gen.error_count + 1)
          error_msg = "Order #{order.order_number}: #{e.message}"
          bulk_gen.update(errors: bulk_gen.errors.push(error_msg))
          broadcast_progress(bulk_gen, "✗ #{error_msg}")
        end

        # Broadcast progress every order
        broadcast_progress(bulk_gen)
      end

      # Mark as completed
      bulk_gen.update(completed_at: Time.current)
      duration = ((Time.current - started_at) / 60).round(2)
      broadcast_completion(bulk_gen, duration)

    rescue StandardError => e
      bulk_gen.update(
        status: 'failed',
        error_message: e.message,
        completed_at: Time.current
      )
      broadcast_error(bulk_gen, e.message)
    end
  end

  private

  def build_delivered_lines(order)
    order.lines.map do |line|
      {
        product_id:          line.product_id,
        qty:                 line.qty.to_d,
        sales_order_line_id: line.id,
        unit_price:          line.unit_price,
        discount_pct:        line.discount_pct,
        hsn_code:            line.hsn_code,
        gst_rate:            line.gst_rate
      }
    end
  end

  def broadcast_progress(bulk_gen, message = nil)
    BulkInvoiceChannel.broadcast_to(
      bulk_gen.session_id,
      {
        type: 'progress',
        message: message,
        completed_count: bulk_gen.completed_count,
        total_count: bulk_gen.total_count,
        error_count: bulk_gen.error_count,
        percent: ((bulk_gen.completed_count.to_f / bulk_gen.total_count) * 100).round(0)
      }
    )
  end

  def broadcast_completion(bulk_gen, duration)
    BulkInvoiceChannel.broadcast_to(
      bulk_gen.session_id,
      {
        type: 'complete',
        message: "Bulk generation completed in #{duration} minutes",
        completed_count: bulk_gen.completed_count,
        total_count: bulk_gen.total_count,
        error_count: bulk_gen.error_count,
        errors: bulk_gen.errors,
        duration_minutes: duration
      }
    )
  end

  def broadcast_error(bulk_gen, error_message)
    BulkInvoiceChannel.broadcast_to(
      bulk_gen.session_id,
      {
        type: 'error',
        message: "Bulk generation failed: #{error_message}"
      }
    )
  end
end
