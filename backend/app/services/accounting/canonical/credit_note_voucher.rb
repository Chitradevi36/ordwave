module Accounting
  module Canonical
    # Canonical representation of a sales return / credit note voucher.
    class CreditNoteVoucher < BaseRecord
      fields :voucher_type,
             :voucher_number,
             :voucher_date,
             :party_ledger_name,
             :original_invoice_number,
             :narration,
             :subtotal,
             :taxable_total,
             :cgst_total,
             :sgst_total,
             :igst_total,
             :cess_total,
             :grand_total,
             :inventory_lines,      # Array<InventoryLine>
             :tax_entries,          # Array<TaxEntry>
             :metadata

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
