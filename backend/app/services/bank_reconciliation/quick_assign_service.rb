# frozen_string_literal: true

module BankReconciliation
  # Handles quick assignment of unmatched transactions based on suggestions
  # One-click execution of suggested actions (assign to customer, mark advance, etc.)
  #
  # Usage:
  #   result = BankReconciliation::QuickAssignService.call(
  #     bank_transaction: txn,
  #     action_type: 'mark_as_advance', # or 'exact_match', 'assign_to_customer'
  #     customer_id: customer.id,
  #     invoice_id: invoice.id, # optional
  #     user: current_user
  #   )
  #   result.success? #=> true/false
  #
  class QuickAssignService
    Result = Struct.new(:success?, :message, :bank_transaction, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bank_transaction:, action_type:, user:, customer_id: nil, invoice_id: nil)
      @txn = bank_transaction
      @action_type = action_type
      @user = user
      @customer_id = customer_id
      @invoice_id = invoice_id
    end

    def call
      case @action_type
      when 'exact_invoice_match'
        execute_exact_match
      when 'mark_as_advance'
        execute_mark_advance
      when 'assign_to_customer'
        execute_assign_to_customer
      when 'ignore_as_error'
        execute_ignore
      else
        failure("Unknown action type: #{@action_type}")
      end
    rescue StandardError => error
      Rails.logger.error("[QuickAssignService] Error: #{error.message}")
      failure("Assignment failed: #{error.message}")
    end

    private

    def execute_exact_match
      return failure("Invoice ID required") unless @invoice_id.present?

      invoice = SalesInvoice.find_by(id: @invoice_id, organization_id: @txn.organization_id)
      return failure("Invoice not found") unless invoice

      return failure("Amount mismatch") unless invoice.total_amount == @txn.amount

      # Mark as matched
      @txn.update!(
        status: :matched,
        matched_customer_id: invoice.customer_id,
        matched_invoice_id: invoice.id,
        reviewed_by_id: @user.id,
        processed_at: Time.current
      )

      # Log audit trail
      Credit::AuditLogger.log(
        organization_id: @txn.organization_id,
        user_id: @user.id,
        action: 'bank_transaction_quick_assign',
        resource_type: 'BankTransaction',
        resource_id: @txn.id,
        changes: {
          status: ['unmatched', 'matched'],
          matched_invoice_id: [nil, invoice.id]
        },
        metadata: { action_type: @action_type, confidence: 100 }
      )

      success("Invoice matched and confirmed")
    end

    def execute_mark_advance
      return failure("Customer ID required") unless @customer_id.present?

      customer = Customer.find_by(id: @customer_id, organization_id: @txn.organization_id)
      return failure("Customer not found") unless customer

      ActiveRecord::Base.transaction do
        # Create payment record
        payment = Payment.create!(
          organization: @txn.organization,
          branch: @txn.bank_account.branch,
          customer: customer,
          amount: @txn.amount,
          payment_mode: :bank_transfer,
          received_date: @txn.txn_date,
          reference_number: @txn.utr_number.presence || @txn.reference_number,
          notes: "Quick-assigned advance from bank reconciliation. Narration: #{@txn.narration}",
          created_by: @user
        )

        # Create advance payment
        AdvancePayment.create!(
          organization: @txn.organization,
          customer: customer,
          amount: @txn.amount,
          source_payment: payment,
          notes: "Auto-assigned from unmatched queue"
        )

        # Mark unmatched txn as matched
        @txn.update!(
          status: :matched,
          matched_customer_id: customer.id,
          matched_payment_id: payment.id,
          reviewed_by_id: @user.id,
          processed_at: Time.current
        )

        # Log audit trail
        Credit::AuditLogger.log(
          organization_id: @txn.organization_id,
          user_id: @user.id,
          action: 'bank_transaction_quick_assign',
          resource_type: 'BankTransaction',
          resource_id: @txn.id,
          changes: {
            status: ['unmatched', 'matched'],
            matched_customer_id: [nil, customer.id],
            matched_payment_id: [nil, payment.id]
          },
          metadata: {
            action_type: @action_type,
            payment_id: payment.id,
            advance_id: AdvancePayment.last.id
          }
        )
      end

      success("Marked as advance payment for #{customer.name}")
    end

    def execute_assign_to_customer
      return failure("Customer ID required") unless @customer_id.present?

      customer = Customer.find_by(id: @customer_id, organization_id: @txn.organization_id)
      return failure("Customer not found") unless customer

      # Create a "holding" advance payment for now
      # The user can later decide to allocate it to invoices
      ActiveRecord::Base.transaction do
        payment = Payment.create!(
          organization: @txn.organization,
          branch: @txn.bank_account.branch,
          customer: customer,
          amount: @txn.amount,
          payment_mode: :bank_transfer,
          received_date: @txn.txn_date,
          reference_number: @txn.utr_number.presence || @txn.reference_number,
          notes: "Quick-assigned to customer from unmatched queue",
          created_by: @user
        )

        @txn.update!(
          status: :matched,
          matched_customer_id: customer.id,
          matched_payment_id: payment.id,
          reviewed_by_id: @user.id,
          processed_at: Time.current
        )

        # Log audit trail
        Credit::AuditLogger.log(
          organization_id: @txn.organization_id,
          user_id: @user.id,
          action: 'bank_transaction_quick_assign',
          resource_type: 'BankTransaction',
          resource_id: @txn.id,
          changes: {
            status: ['unmatched', 'matched'],
            matched_customer_id: [nil, customer.id]
          },
          metadata: {
            action_type: @action_type,
            payment_id: payment.id,
            note: 'Pending customer allocation decision'
          }
        )
      end

      success("Assigned to #{customer.name}. Payment created and awaiting allocation.")
    end

    def execute_ignore
      @txn.update!(
        status: :ignored,
        reviewed_by_id: @user.id,
        processed_at: Time.current
      )

      # Log audit trail
      Credit::AuditLogger.log(
        organization_id: @txn.organization_id,
        user_id: @user.id,
        action: 'bank_transaction_quick_assign',
        resource_type: 'BankTransaction',
        resource_id: @txn.id,
        changes: {
          status: ['unmatched', 'ignored']
        },
        metadata: {
          action_type: @action_type,
          reason: 'Marked as error/fee by user'
        }
      )

      success("Marked as error and ignored")
    end

    def success(message)
      Result.new(
        success?: true,
        message: message,
        bank_transaction: @txn,
        errors: []
      )
    end

    def failure(error_msg)
      Result.new(
        success?: false,
        message: nil,
        bank_transaction: @txn,
        errors: [error_msg]
      )
    end
  end
end
