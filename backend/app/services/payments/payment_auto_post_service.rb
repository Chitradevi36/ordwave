module Payments
  class PaymentAutoPostService
    include ServiceResult

    # Inputs:
    # - bank_transaction: BankTransaction
    # - confidence_score: Float (0-100)
    # - matching_invoice: Invoice
    # - configuration: Hash (confidence thresholds, etc.)
    #
    # Output: Result { success?, action: Symbol, payment?: Payment, ... }

    def initialize(bank_transaction:, confidence_score:, matching_invoice:, configuration: nil)
      @bank_transaction = bank_transaction
      @confidence_score = confidence_score
      @matching_invoice = matching_invoice
      @configuration = configuration || load_default_configuration
    end

    def call
      validate_inputs
      return if failed?

      route_based_on_confidence
    end

    private

    def validate_inputs
      return failure("Bank transaction not found") unless @bank_transaction.present?
      return failure("Confidence score not provided") unless @confidence_score.present?
      return failure("Matching invoice not found") unless @matching_invoice.present?
      success
    end

    def route_based_on_confidence
      auto_post_threshold = @configuration['auto_post_threshold'].to_i || 95
      suggestion_threshold = @configuration['suggestion_threshold'].to_i || 85

      case @confidence_score
      when auto_post_threshold..100
        auto_post_transaction
      when suggestion_threshold...auto_post_threshold
        create_suggestion
      else
        route_to_manual_review
      end
    end

    def auto_post_transaction
      result = {}

      ActiveRecord::Base.transaction do
        # 1. Create Payment
        payment = create_payment_record
        result[:payment] = payment

        # 2. Update Invoice
        update_invoice_status(payment)

        # 3. Create Audit Trail
        create_audit_trail(payment, action: 'auto_posted')

        # 4. Notify Finance & Customer
        notify_auto_post(payment)

        # 5. Schedule rejection window handler
        schedule_rejection_window_job(payment)

        result[:action] = :auto_posted
        result[:ok] = true
      end

      success(result)
    rescue ActiveRecord::RecordInvalid => e
      failure("Failed to auto-post payment: #{e.message}")
    rescue => e
      failure("Unexpected error during auto-posting: #{e.message}")
    end

    def create_suggestion
      result = {}

      ActiveRecord::Base.transaction do
        suggestion = PaymentSuggestion.create!(
          bank_transaction: @bank_transaction,
          invoice: @matching_invoice,
          confidence_score: @confidence_score,
          confidence_breakdown: build_confidence_breakdown,
          status: 'pending_approval'
        )

        result[:suggestion] = suggestion
        result[:action] = :suggestion_created
        result[:ok] = true

        # Notify Finance
        notify_payment_suggestion(suggestion)
      end

      success(result)
    rescue ActiveRecord::RecordInvalid => e
      failure("Failed to create suggestion: #{e.message}")
    rescue => e
      failure("Unexpected error creating suggestion: #{e.message}")
    end

    def route_to_manual_review
      result = {}

      ActiveRecord::Base.transaction do
        manual_item = create_manual_review_item
        result[:manual_item] = manual_item
        result[:action] = :routed_to_manual
        result[:ok] = true

        # Notify Finance
        notify_manual_review(manual_item)
      end

      success(result)
    rescue => e
      failure("Failed to route to manual review: #{e.message}")
    end

    def create_payment_record
      Payment.create!(
        organization: @matching_invoice.organization,
        branch: @matching_invoice.branch,
        customer: @matching_invoice.customer,
        amount: @bank_transaction.amount,
        payment_method: 'bank_transfer',
        payment_mode: 'bank_transfer',
        received_date: @bank_transaction.date,
        reference_number: @bank_transaction.reference,
        created_by: User.system_user,  # System auto-posting
        confidence_score: @confidence_score,
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now,
        status: 'confirmed'
      )
    end

    def update_invoice_status(payment)
      @matching_invoice.update!(
        payment_received_at: Time.current,
        amount_paid: @bank_transaction.amount,
        status: 'paid'
      )

      # Create payment allocation if needed
      PaymentAllocation.create!(
        payment: payment,
        sales_invoice: @matching_invoice,
        amount: @bank_transaction.amount
      )
    end

    def create_audit_trail(payment, action:)
      AutoPostAudit.create!(
        payment: payment,
        bank_transaction: @bank_transaction,
        confidence_breakdown: build_confidence_breakdown,
        auto_posted: (action == 'auto_posted'),
        action: action,
        actor: User.system_user,
        timestamp: Time.current,
        audit_notes: "Auto-posted at #{@confidence_score}% confidence via system"
      )
    end

    def create_manual_review_item
      ManualPaymentReview.create!(
        bank_transaction: @bank_transaction,
        suggested_invoice: @matching_invoice,
        confidence_score: @confidence_score,
        reason: 'low_confidence',
        status: 'pending_review',
        notes: "Confidence score #{@confidence_score}% below threshold"
      )
    end

    def schedule_rejection_window_job(payment)
      # Use Sidekiq to check if payment was rejected after 1 hour
      RejectPaymentWindowJob.perform_at(
        1.hour.from_now,
        payment.id
      )
    end

    def build_confidence_breakdown
      {
        score: @confidence_score,
        timestamp: Time.current,
        components: {
          amount: 'calculated',
          date: 'calculated',
          customer: 'calculated',
          reference: 'calculated'
        }
      }
    end

    def notify_auto_post(payment)
      # SMS to Finance lead
      send_notification(
        type: :sms,
        recipient: finance_lead,
        template: 'payment_auto_posted',
        data: {
          payment_id: payment.id,
          amount: payment.amount,
          invoice_number: @matching_invoice.invoice_number,
          customer_name: @matching_invoice.customer.name,
          rejection_link: rejection_link(payment)
        }
      )

      # SMS to Customer
      send_notification(
        type: :sms,
        recipient: @matching_invoice.customer,
        template: 'payment_received',
        data: {
          amount: payment.amount,
          invoice_number: @matching_invoice.invoice_number,
          date: payment.received_date
        }
      )
    end

    def notify_payment_suggestion(suggestion)
      send_notification(
        type: :sms,
        recipient: finance_lead,
        template: 'payment_suggestion',
        data: {
          suggestion_id: suggestion.id,
          confidence: suggestion.confidence_score,
          amount: suggestion.invoice.total,
          invoice_number: suggestion.invoice.invoice_number,
          approval_link: suggestion_link(suggestion)
        }
      )
    end

    def notify_manual_review(manual_item)
      send_notification(
        type: :sms,
        recipient: finance_lead,
        template: 'payment_manual_review',
        data: {
          review_id: manual_item.id,
          confidence: manual_item.confidence_score,
          reason: manual_item.reason,
          amount: manual_item.suggested_invoice&.total,
          review_link: manual_review_link(manual_item)
        }
      )
    end

    def send_notification(type:, recipient:, template:, data:)
      case type
      when :sms
        send_sms_notification(recipient, template, data)
      when :email
        send_email_notification(recipient, template, data)
      when :in_app
        send_in_app_notification(recipient, template, data)
      end
    rescue => e
      Rails.logger.error("Failed to send #{type} notification: #{e.message}")
    end

    def send_sms_notification(recipient, template, data)
      # Integration with SMS service (Twilio, etc.)
      # This is a placeholder - actual implementation depends on SMS service setup
      Rails.logger.info("SMS Notification [#{template}]: #{data.inspect}")
    end

    def send_email_notification(recipient, template, data)
      # Integration with email service
      Rails.logger.info("Email Notification [#{template}]: #{data.inspect}")
    end

    def send_in_app_notification(recipient, template, data)
      # Create in-app notification record
      Rails.logger.info("In-App Notification [#{template}]: #{data.inspect}")
    end

    def finance_lead
      # Return the finance team lead or finance manager role
      User.with_role('finance_manager').first || User.with_role('finance').first
    end

    def rejection_link(payment)
      "/api/v1/payments/#{payment.id}/reject-auto-post"
    end

    def suggestion_link(suggestion)
      "/api/v1/payment-suggestions/#{suggestion.id}/approve"
    end

    def manual_review_link(manual_item)
      "/finance/payment-reviews/#{manual_item.id}"
    end

    def load_default_configuration
      config = ConfidenceAdjustment.latest
      config&.to_configuration_hash || {
        'auto_post_threshold' => 95,
        'suggestion_threshold' => 85,
        'rejection_window_minutes' => 60,
        'amount_tolerance_pct' => 2.0,
        'date_tolerance_days' => 3,
        'customer_fuzzy_minimum' => 0.80,
        'reference_weight' => 15
      }
    rescue
      {
        'auto_post_threshold' => 95,
        'suggestion_threshold' => 85,
        'rejection_window_minutes' => 60,
        'amount_tolerance_pct' => 2.0,
        'date_tolerance_days' => 3,
        'customer_fuzzy_minimum' => 0.80,
        'reference_weight' => 15
      }
    end
  end
end
