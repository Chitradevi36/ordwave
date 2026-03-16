# frozen_string_literal: true

module Invoicing
  # Reprocesses a quarantined invoice generation attempt
  # Retries the invoice generation from the saved context
  #
  # Usage:
  #   result = Invoicing::ReprocessQuarantineService.call(
  #     quarantine: quarantine_record,
  #     user: current_user
  #   )
  #   result.success? #=> true/false
  #   result.invoice #=> Generated invoice or nil
  #
  class ReprocessQuarantineService
    Result = Struct.new(:success?, :invoice, :message, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(quarantine:, user:)
      @quarantine = quarantine
      @user = user
    end

    def call
      return failure("Quarantine already resolved") unless @quarantine.unresolved?

      stop = @quarantine.trip_stop
      order = @quarantine.sales_order

      return failure("Trip stop not found") unless stop.present?
      return failure("Order not found") unless order.present?

      # Retry the invoice generation with the stored context
      begin
        @quarantine.update!(status: 'processing')

        # Use the stored delivered_lines from when it was quarantined
        delivered_lines = @quarantine.delivered_lines || {}
        return failure("No delivered lines data for reprocessing") if delivered_lines.empty?

        actor = stop.delivery_trip.driver || order.created_by

        result = Invoice::GenerateFromDeliveryService.call(
          actor:             actor,
          branch:            order.branch,
          customer:          order.customer,
          sales_order:       order,
          trip_stop:         stop,
          invoice_date:      stop.delivered_at&.to_date || Date.current,
          generation_source: 'manual_reprocess_from_quarantine',
          delivered_lines:   reformat_delivered_lines(delivered_lines)
        )

        if result.success?
          @quarantine.update!(
            status: 'resolved',
            resolved_at: Time.current,
            resolved_by: @user
          )

          # Log audit trail
          Credit::AuditLogger.log(
            organization_id: @quarantine.organization_id,
            user_id: @user.id,
            action: 'quarantine_reprocess_success',
            resource_type: 'InvoiceGenerationQuarantine',
            resource_id: @quarantine.id,
            changes: {
              status: ['quarantined', 'resolved'],
              resolved_at: [nil, Time.current]
            },
            metadata: {
              invoice_id: result.invoice.id,
              invoice_number: result.invoice.invoice_number,
              retry_count: @quarantine.retry_count + 1
            }
          )

          success(
            invoice: result.invoice,
            message: "Invoice #{result.invoice.invoice_number} generated successfully"
          )
        else
          # Update retry count
          @quarantine.update!(
            status: 'quarantined',
            retry_count: @quarantine.retry_count + 1,
            last_retry_at: Time.current,
            error_message: result.errors.join(', ')
          )

          failure("Reprocessing failed: #{result.errors.join(', ')}")
        end
      rescue StandardError => error
        @quarantine.update!(
          status: 'quarantined',
          retry_count: @quarantine.retry_count + 1,
          last_retry_at: Time.current,
          error_message: error.message
        )

        Rails.logger.error("[ReprocessQuarantineService] Error: #{error.message}")
        failure("Error during reprocessing: #{error.message}")
      end
    end

    private

    def reformat_delivered_lines(stored_lines)
      # Convert stored JSONB format back to the format expected by GenerateFromDeliveryService
      stored_lines.map do |line|
        {
          product_id: line['product_id'],
          qty: line['qty'].to_d,
          sales_order_line_id: line['sales_order_line_id'],
          unit_price: line['unit_price'].to_d,
          discount_pct: line['discount_pct'].to_d,
          hsn_code: line['hsn_code'],
          gst_rate: line['gst_rate'].to_d
        }
      end
    end

    def success(invoice:, message:)
      Result.new(
        success?: true,
        invoice: invoice,
        message: message,
        errors: []
      )
    end

    def failure(error_msg)
      Result.new(
        success?: false,
        invoice: nil,
        message: nil,
        errors: [error_msg]
      )
    end
  end
end
