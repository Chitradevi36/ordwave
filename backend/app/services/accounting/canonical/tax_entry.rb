module Accounting
  module Canonical
    # A single tax component on a line or at voucher level.
    # tax_type:   "cgst" | "sgst" | "igst" | "cess" | "vat" | "other"
    # ledger_kind: "output_tax" | "input_tax" | "other"
    class TaxEntry < BaseRecord
      fields :tax_type,
             :rate,
             :amount,
             :ledger_kind,
             :label

      # Convenience: human-readable label when not explicitly set.
      def display_label
        label.presence || "#{tax_type.to_s.upcase} #{rate}%"
      end
    end
  end
end
