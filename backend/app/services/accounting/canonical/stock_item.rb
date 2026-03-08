module Accounting
  module Canonical
    # Represents a product/item for provider stock master sync.
    # gst_rate is the combined rate; cgst/sgst/igst are split components.
    class StockItem < BaseRecord
      fields :name,
             :sku,
             :item_code,
             :hsn_code,
             :uom,
             :gst_rate,
             :cgst_rate,
             :sgst_rate,
             :igst_rate,
             :cess_rate,
             :active

      def active?
        active != false
      end
    end
  end
end
