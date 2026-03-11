# frozen_string_literal: true

module BankReconciliation
  # PostingService creates a Payment + PaymentAllocations + optional AdvancePayment
  # from a confirmed BankTransactionMatch.
  #
  # Usage:
  #   result = BankReconciliation::PostingService.call(
  #     bank_transaction: txn,
  #     allocations:      [{ invoice_id: 5, amount: 1000.0 }, ...],
  #     reviewed_by:      current_user
  #   )
  #   result.success?       # => true / false
  #   result.payment        # => Payment instance
  #   result.errors         # => Array<String>
  class PostingService
    Result = Struct.new(:success, :payment, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(bank_transaction:, allocations:, reviewed_by:)
      new(
        bank_transaction: bank_transaction,
        allocations:      allocations,
        reviewed_by:      reviewed_by
      ).call
    end

    def initialize(bank_transaction:, allocations:, reviewed_by:)
      @txn         = bank_transaction
      @allocations = allocations
      @reviewed_by = reviewed_by
      @errors      = []
    end

    def call
      return already_posted_error if @txn.matched_payment_id.present?
      return no_allocations_error if @allocations.blank?

      validate_allocations
      return failure if @errors.any?

      posted_payment = nil

      ActiveRecord::Base.transaction do
        customer = resolve_customer
        raise ActiveRecord::Rollback, "Customer not found" unless customer

        posted_payment = create_payment(customer)
        allocated_total = create_allocations(posted_payment)
        handle_excess(posted_payment, customer, allocated_total)

        @txn.update!(
          status:             :matched,
          matched_payment_id: posted_payment.id,
          matched_customer_id: customer.id,
          reviewed_by_id:     @reviewed_by.id,
          processed_at:       Time.current
        )

        mark_references_matched
      end

      Result.new(success: true, payment: posted_payment, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, payment: nil, errors: [e.message])
    rescue StandardError => e
      Rails.logger.error("[BankReconciliation::PostingService] #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      Result.new(success: false, payment: nil, errors: [e.message])
    end

    private

    def validate_allocations
      total = @allocations.sum { |a| a[:amount].to_d }
      if total > @txn.amount
        @errors << "Allocated amount (#{total}) exceeds transaction amount (#{@txn.amount})"
      end
      @allocations.each do |a|
        unless SalesInvoice.exists?(id: a[:invoice_id])
          @errors << "Invoice ##{a[:invoice_id]} not found"
        end
      end
    end

    def resolve_customer
      # Prefer the customer from the selected match candidate
      selected = @txn.candidates.selected.first
      return Customer.find_by(id: selected.customer_id) if selected&.customer_id

      first_invoice_id = @allocations.first[:invoice_id]
      SalesInvoice.find(first_invoice_id).customer
    end

    def create_payment(customer)
      Payment.create!(
        organization:     @txn.organization,
        branch:           @txn.bank_account.branch,
        customer:         customer,
        amount:           @txn.amount,
        payment_mode:     :bank_transfer,
        received_date:    @txn.txn_date,
        reference_number: @txn.utr_number.presence || @txn.reference_number,
        notes:            "Auto-posted from bank reconciliation. Narration: #{@txn.narration}",
        created_by:       @reviewed_by
      )
    end

    def create_allocations(payment)
      total = 0.to_d
      @allocations.each do |alloc|
        invoice = SalesInvoice.find(alloc[:invoice_id])
        amount  = alloc[:amount].to_d

        PaymentAllocation.create!(
          payment:           payment,
          sales_invoice:     invoice,
          allocated_amount:  amount
        )

        total += amount
        update_invoice_status(invoice)
      end
      total
    end

    def update_invoice_status(invoice)
      invoice.reload
      outstanding = invoice.outstanding_amount.to_d

      if outstanding <= 0
        invoice.update!(status: :paid)
      elsif outstanding < invoice.grand_total
        invoice.update!(status: :partially_paid)
      end
    end

    def handle_excess(payment, customer, allocated_total)
      excess = @txn.amount.to_d - allocated_total
      return unless excess > 0

      AdvancePayment.create!(
        organization:   @txn.organization,
        customer:       customer,
        amount:         excess,
        source_payment: payment,
        notes:          "Excess from bank reconciliation transaction #{@txn.id}"
      )
    end

    def mark_references_matched
      utrs = [@txn.utr_number, @txn.reference_number].compact
      ((@txn.match_meta&.dig("utr_candidates")) || []).concat(utrs).uniq.each do |val|
        ExpectedPaymentReference
          .pending
          .where("UPPER(reference_value) = ?", val.upcase)
          .update_all(status: :matched, matched_at: Time.current)
      end
    end

    def already_posted_error
      Result.new(success: false, payment: nil,
                 errors: ["Transaction #{@txn.id} has already been posted (payment ##{@txn.matched_payment_id})"])
    end

    def no_allocations_error
      Result.new(success: false, payment: nil, errors: ["No allocations provided"])
    end

    def failure
      Result.new(success: false, payment: nil, errors: @errors)
    end
  end
end
