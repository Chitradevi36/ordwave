module Accounting
  module Canonical
    # Canonical representation of an outbound sales (invoice) voucher.
    # inventory_lines: Array<InventoryLine>
    # tax_entries:     Array<TaxEntry> — aggregated at voucher level
    # metadata:        plain Hash for source refs and debug info
    class SalesVoucher < BaseRecord
      fields :voucher_type,
             :voucher_number,
             :voucher_date,
             :party_ledger_name,
             :place_of_supply_state,
             :narration,
             :subtotal,
             :discount_total,
             :taxable_total,
             :cgst_total,
             :sgst_total,
             :igst_total,
             :cess_total,
             :round_off_amount,
             :grand_total,
             :inventory_lines,      # Array<InventoryLine>
             :tax_entries,          # Array<TaxEntry>
             :metadata              # Hash

      def to_h
        base = super
        base[:inventory_lines] = Array(inventory_lines).map(&:to_h)
        base[:tax_entries]     = Array(tax_entries).map(&:to_h)
        base[:metadata]        = metadata || {}
        base
      end
    end
  end
end
