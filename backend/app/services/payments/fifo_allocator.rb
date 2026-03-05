module Payments
  # Allocates a payment amount across outstanding invoices for a customer,
  # oldest-first (FIFO by invoice_date).
  #
  # Returns a Result struct:
  #   result.allocations  — Array of { invoice:, allocated: }
  #   result.unallocated  — Remaining amount after all invoices exhausted
  #
  # NOTE: Does NOT persist — caller decides when to write allocations.
  class FifoAllocator
    Result = Struct.new(:allocations, :unallocated, keyword_init: true)

    # @param customer       [Customer]
    # @param amount         [Numeric]   total payment amount to allocate
    # @param invoices       [Array<SalesInvoice>] optional override; defaults to FIFO outstanding
    def self.run(customer:, amount:, invoices: nil)
      new(customer: customer, amount: amount, invoices: invoices).run
    end

    def initialize(customer:, amount:, invoices:)
      @customer   = customer
      @amount     = amount.to_d
      @invoices   = invoices
    end

    def run
      remaining    = @amount
      allocations  = []

      invoices_to_allocate.each do |invoice|
        break if remaining <= 0

        allocatable = [invoice.outstanding_amount.to_d, remaining].min
        next if allocatable <= 0

        allocations << { invoice: invoice, allocated: allocatable }
        remaining -= allocatable
      end

      Result.new(allocations: allocations, unallocated: remaining)
    end

    private

    def invoices_to_allocate
      @invoices ||= SalesInvoice
        .where(customer: @customer, status: %w[issued partially_paid])
        .where('outstanding_amount > 0')
        .order(:invoice_date, :created_at)
    end
  end
end
