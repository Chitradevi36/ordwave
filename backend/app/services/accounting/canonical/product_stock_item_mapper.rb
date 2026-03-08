module Accounting
  module Canonical
    # Maps a Product to a canonical StockItem.
    #
    # OMS Product fields used:
    #   name                      -> name
    #   sku                       -> sku + item_code
    #   hsn_sac_code.code         -> hsn_code  (via product.hsn_code delegate)
    #   units_of_measure.symbol   -> uom
    #   gst_rate                  -> gst_rate
    #   gsplit_rates              -> cgst_rate / sgst_rate / igst_rate  (from Product#gsplit_rates)
    #   status                    -> active
    class ProductStockItemMapper < BaseMapper
      def call
        product = record

        name = require_present!(
          fetch_first_present(product, :name),
          "product name"
        )

        sku      = string_value(fetch_first_present(product, :sku, :code, :item_code))
        hsn_code = string_value(fetch_first_present(product, :hsn_code, :hsn_sac_code_code))
        uom      = resolve_uom(product)
        gst_rate = decimal!(product.try(:gst_rate))

        # Product#gsplit_rates returns { cgst: N, sgst: N, igst: N }
        split    = product.try(:gsplit_rates) || {}
        cgst     = decimal(split[:cgst] || split["cgst"]) || (gst_rate / 2).round(2)
        sgst     = decimal(split[:sgst] || split["sgst"]) || (gst_rate / 2).round(2)
        igst     = decimal(split[:igst] || split["igst"]) || gst_rate

        StockItem.new(
          name:       name,
          sku:        sku,
          item_code:  sku,
          hsn_code:   hsn_code,
          uom:        uom,
          gst_rate:   gst_rate,
          cgst_rate:  cgst,
          sgst_rate:  sgst,
          igst_rate:  igst,
          cess_rate:  decimal(product.try(:cess_rate)),
          active:     product.try(:status).to_s == "active"
        )
      end

      private

      def resolve_uom(product)
        # Prefer units_of_measure.symbol, fall back to units_of_measure.name
        uom_obj = product.try(:units_of_measure)
        return nil if uom_obj.nil?
        string_value(fetch_first_present(uom_obj, :symbol, :short_name, :name, :abbreviation))
      end
    end
  end
end
