module Accounting
  module Canonical
    # Links a receipt/payment to an invoice allocation.
    # bill_type: "new_ref" | "against_ref" | "on_account" | "advance"
    class BillAllocation < BaseRecord
      fields :bill_name,
             :bill_type,
             :amount,
             :reference_date,
             :notes
    end
  end
end
