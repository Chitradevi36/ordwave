module Accounting
  module Canonical
    # Canonical representation of a payment/receipt voucher.
    # bill_allocations: Array<BillAllocation>
    class ReceiptVoucher < BaseRecord
      fields :voucher_type,
             :voucher_number,
             :voucher_date,
             :party_ledger_name,
             :receipt_ledger_name,
             :amount,
             :reference_number,
             :narration,
             :bill_allocations,     # Array<BillAllocation>
             :metadata

      def to_h
        base = super
        base[:bill_allocations] = Array(bill_allocations).map(&:to_h)
        base[:metadata]         = metadata || {}
        base
      end
    end
  end
end
