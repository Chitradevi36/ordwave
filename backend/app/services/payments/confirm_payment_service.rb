module Payments
  # Confirms a draft payment, runs FIFO allocation, updates invoice outstanding,
  # syncs credit account, and creates advance if payment exceeds outstanding.
  #
  # Usage:
  #   result = Payments::ConfirmPaymentService.call(
  #     actor:           current_user,
  #     payment:         payment,
  #     manual_lines:    [{ sales_invoice_id: 1, amount: 500 }]  # optional
  #   )
  #   result.success?
  #   result.payment
  #   result.errors
  class ConfirmPaymentService
    Result = Struct.new(:success?, :payment, :advance_payment, :errors, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    # @param actor         [User]
    # @param payment       [Payment]
    # @param manual_lines  [Array<Hash>] optional explicit allocation overrides
    def initialize(actor:, payment:, manual_lines: nil)
      @actor        = actor
      @payment      = payment
      @manual_lines = manual_lines
      @errors       = []
    end

    def call
      return failure(['Payment is not in draft status']) unless @payment.draft?
      return failure(['Payment amount must be positive']) unless @payment.amount.to_d > 0

      ActiveRecord::Base.transaction do
        alloc_result = run_allocation
        write_allocations(alloc_result.allocations)

        advance = create_advance_if_needed(alloc_result.unallocated)

        # Confirm the payment
        @payment.update!(
          status:             'confirmed',
          confirmed_at:       Time.current,
          allocated_amount:   @payment.amount.to_d - alloc_result.unallocated,
          unallocated_amount: alloc_result.unallocated
        )

        Payments::CreditSyncService.call(
          customer:     @payment.customer,
          organization: @payment.organization
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @payment.organization,
          auditable:    @payment,
          action:       'payment_confirmed',
          changes:      {
            amount:     @payment.amount,
            mode:       @payment.payment_mode,
            allocated:  @payment.allocated_amount,
            advance:    advance&.original_amount
          }
        )

        notify_accountants

        result = Result.new(
          success?:        true,
          payment:         @payment,
          advance_payment: advance,
          errors:          []
        )

        # Fire webhook after commit guard
        WebhookEvents.fire(
          organization: @payment.organization,
          event:        'payment.received',
          payload:      WebhookEvents.payment_payload(@payment)
        )

        return result
      end
    rescue ActiveRecord::RecordInvalid => e
      failure([e.message])
    end

    private

    def run_allocation
      if @manual_lines.present?
        build_manual_allocation
      else
        FifoAllocator.run(
          customer: @payment.customer,
          amount:   @payment.amount.to_d
        )
      end
    end

    # Manual allocation from caller-provided lines
    def build_manual_allocation
      remaining   = @payment.amount.to_d
      allocations = []

      @manual_lines.each do |line|
        invoice = SalesInvoice.find_by(
          id:           line[:sales_invoice_id],
          organization: @payment.organization
        )
        next unless invoice && invoice.outstanding_amount.to_d > 0

        capped = [line[:amount].to_d, invoice.outstanding_amount.to_d, remaining].min
        next if capped <= 0

        allocations << { invoice: invoice, allocated: capped }
        remaining  -= capped
      end

      FifoAllocator::Result.new(allocations: allocations, unallocated: remaining)
    end

    def write_allocations(allocations)
      allocations.each do |row|
        invoice   = row[:invoice]
        allocated = row[:allocated]

        PaymentAllocation.create!(
          payment:          @payment,
          sales_invoice:    invoice,
          allocated_amount: allocated,
          status:           'active'
        )

        new_paid        = (invoice.paid_amount.to_d + allocated).round(2)
        new_outstanding = (invoice.outstanding_amount.to_d - allocated).round(2)
        # Correct status: 'paid' when fully settled, 'partially_paid' otherwise.
        new_status      = new_outstanding <= 0 ? 'paid' : 'partially_paid'

        invoice.update_columns(
          paid_amount:        new_paid,
          outstanding_amount: [new_outstanding, 0].max,
          status:             new_status
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @payment.organization,
          auditable:    invoice,
          action:       'payment_allocation_created',
          changes:      {
            payment_id:       @payment.id,
            payment_number:   @payment.payment_number,
            allocated_amount: allocated,
            outstanding_after: invoice.outstanding_amount
          }
        )
      end
    end

    def create_advance_if_needed(unallocated)
      return nil unless unallocated > 0

      advance = AdvancePayment.create!(
        organization:    @payment.organization,
        branch:          @payment.branch,
        customer:        @payment.customer,
        source_payment:  @payment,
        original_amount: unallocated,
        balance:         unallocated,
        status:          'unapplied',
        notes:           "Auto-created from payment #{@payment.payment_number}"
      )

      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @payment.organization,
        auditable:    advance,
        action:       'advance_payment_created',
        changes:      { amount: unallocated, source_payment: @payment.payment_number }
      )

      advance
    end

    def notify_accountants
      accountants = User.joins(:memberships)
                        .where(memberships: {
                          organization_id: @payment.organization_id,
                          deleted_at:      nil,
                          active:          true
                        })
                        .joins(memberships: :role)
                        .where(roles: { name: %w[owner admin accountant] })
                        .distinct

      Notifications::CreateService.call(
        organization: @payment.organization,
        recipients:   accountants,
        actor:        @actor,
        notifiable:   @payment,
        type:         'payment_confirmed',
        title:        "Payment confirmed \u2014 \u20b9#{@payment.amount.to_i.to_s(:delimited)}",
        body:         "From #{@payment.customer&.name} via #{@payment.payment_mode&.humanize}",
        deep_link:    '/finance',
        severity:     'medium'
      )
    rescue StandardError => e
      Rails.logger.warn("[ConfirmPaymentService] Notification failed: #{e.message}")
    end

    def failure(errors)
      Result.new(success?: false, payment: @payment, advance_payment: nil, errors: errors)
    end
  end
end
