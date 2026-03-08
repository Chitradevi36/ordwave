module Accounting
  module Canonical
    # One product line in a sales/purchase/credit-note voucher.
    # All monetary fields are expected as BigDecimal or Numeric, never Float literals.
    # tax_entries: array of TaxEntry for per-line tax detail.
    class InventoryLine < BaseRecord
      fields :item_name,
             :sku,
             :item_code,
             :hsn_code,
             :quantity,
             :uom,
             :rate,
             :gross_amount,
             :discount_amount,
             :taxable_amount,
             :gst_rate,
             :cgst_rate,
             :sgst_rate,
             :igst_rate,
             :cess_rate,
             :cgst_amount,
             :sgst_amount,
             :igst_amount,
             :cess_amount,
             :total_amount,
             :batch_code,
             :warehouse_name,
             :notes,
             :tax_entries        # Array<TaxEntry>

      def to_h
        base = super
        base[:tax_entries] = Array(tax_entries).map(&:to_h)
        base
      end
    end
  end
end
