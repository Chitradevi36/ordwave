module Accounting
  module Canonical
    # Canonical representation of a supplier purchase invoice voucher.
    # tax_entries carry input-tax ledger_kind for CGST/SGST/IGST input credits.
    class PurchaseVoucher < BaseRecord
      fields :voucher_type,
             :voucher_number,
             :voucher_date,
             :supplier_ledger_name,
             :supplier_invoice_number,
             :reverse_charge,
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
