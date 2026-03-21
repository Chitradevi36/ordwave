module Payments
  class PaymentRejectionService
    include ServiceResult

    # Inputs:
    # - payment: Payment (auto-posted)
    # - rejection_reason: String (optional)
    # - actor: User
    #
    # Output: Result { success?, payment?, errors? }

    def initialize(payment:, rejection_reason: nil, actor: nil)
      @payment = payment
      @rejection_reason = rejection_reason || 'Bank match rejected by finance'
      @actor = actor
    end

    def call
      validate_inputs
      return if failed?

      process_rejection
    end

    private

    def validate_inputs
      return failure("Payment not found") unless @payment.present?
      return failure("Payment must be auto-posted to reject") unless @payment.auto_posted?
      return failure("Rejection window has expired") if payment_window_expired?
      success
    end

    def payment_window_expired?
      @payment.rejection_window_expires_at.nil? || 
        Time.current > @payment.rejection_window_expires_at
    end

    def process_rejection
      ActiveRecord::Base.transaction do
        # 1. Reverse Payment
        reverse_payment

        # 2. Revert Invoice Status
        revert_invoice_status

        # 3. Create Rejection Audit
        create_rejection_audit

        # 4. Log ML Feedback
        log_rejection_feedback

        # 5. Route to Manual Queue
        route_to_manual_queue

        # 6. Notify Finance
        notify_rejection

        success({ payment: @payment })
      end
    rescue ActiveRecord::RecordInvalid => e
      failure("Failed to reject payment: #{e.message}")
    rescue => e
      failure("Unexpected error during rejection: #{e.message}")
    end

    def reverse_payment
      @payment.update!(
        status: 'reversed',
        reversed_at: Time.current,
        reversal_reason: @rejection_reason,
        reversed_by: @actor
      )
    end

    def revert_invoice_status
      invoice = @payment.sales_invoices.first
      return unless invoice.present?

      # Remove payment allocation
      PaymentAllocation.where(payment: @payment, sales_invoice: invoice).destroy_all

      # Reset invoice to unpaid
      invoice.update!(
        payment_received_at: nil,
        amount_paid: 0,
        status: 'pending_payment'
      )
    end

    def create_rejection_audit
      AutoPostAudit.create!(
        payment: @payment,
        bank_transaction: @payment.bank_transaction,
        auto_posted: false,
        action: 'rejected_by_finance',
        actor: @actor,
        timestamp: Time.current,
        audit_notes: "Rejected by #{@actor&.name || 'system'}: #{@rejection_reason}",
        confidence_breakdown: {
          original_score: @payment.confidence_score,
          rejection_reason: @rejection_reason
        }
      )
    end

    def log_rejection_feedback
      RejectionFeedback.create!(
        payment: @payment,
        confidence_score: @payment.confidence_score,
        rejection_reason: @rejection_reason,
        timestamp: Time.current
      )
    end

    def route_to_manual_queue
      invoice = @payment.sales_invoices.first
      return unless invoice.present?

      bank_transaction = @payment.bank_transaction
      return unless bank_transaction.present?

      # Create manual review item
      ManualPaymentReview.create!(
        bank_transaction: bank_transaction,
        suggested_invoice: invoice,
        confidence_score: @payment.confidence_score,
        reason: 'rejected_auto_post',
        status: 'pending_review',
        notes: "Auto-post rejected: #{@rejection_reason}"
      )
    end

    def notify_rejection
      invoice = @payment.sales_invoices.first
      return unless invoice.present?

      send_notification(
        type: :sms,
        template: 'payment_rejection_notification',
        data: {
          payment_id: @payment.id,
          amount: @payment.amount,
          invoice_number: invoice.invoice_number,
          reason: @rejection_reason,
          manual_review_link: "/finance/payment-reviews"
        }
      )
    end

    def send_notification(type:, template:, data:)
      case type
      when :sms
        Rails.logger.info("Notification [#{template}]: #{data.inspect}")
      when :email
        Rails.logger.info("Email [#{template}]: #{data.inspect}")
      when :in_app
        Rails.logger.info("In-App [#{template}]: #{data.inspect}")
      end
    rescue => e
      Rails.logger.error("Failed to send notification: #{e.message}")
    end
  end
end
