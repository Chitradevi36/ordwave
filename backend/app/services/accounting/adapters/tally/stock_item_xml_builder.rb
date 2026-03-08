# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally STOCKITEM master import XML fragment from a canonical StockItem.
      #
      # Produces a TALLYMESSAGE > STOCKITEM element suitable for a master
      # import envelope (REPORTNAME: "All Masters").
      #
      # Calibration notes are inline where Tally field behaviour may vary.
      class StockItemXmlBuilder < BaseXmlBuilder
        def export_kind = :master
        def report_name = XmlHelper::REPORT_ALL_MASTERS

        # -----------------------------------------------------------------------
        # Template method implementation
        # -----------------------------------------------------------------------

        def build_message(xml)
          xml.STOCKITEM(NAME: sanitize_name(item_name), ACTION: XmlHelper::ACTION_CREATE) do
            build_stock_item_message(xml)
          end
        end

        # -----------------------------------------------------------------------
        # Named helpers
        # -----------------------------------------------------------------------

        def item_name
          sanitize_name(field(:name).to_s)
        end

        def alias_name
          field(:alias_name).to_s.strip
        end

        def hsn_code
          field(:hsn_code).to_s.strip
        end

        def uom_name
          field(:uom_name).to_s.strip.presence || "Nos"
        end

        def gst_rate
          field(:gst_rate)
        end

        def cgst_rate
          field(:cgst_rate)
        end

        def sgst_rate
          field(:sgst_rate)
        end

        def igst_rate
          field(:igst_rate)
        end

        # -----------------------------------------------------------------------
        protected
        # -----------------------------------------------------------------------

        def build_stock_item_message(xml)
          add_simple_node(xml, "NAME", item_name)

          # PARENT: inventory group in Tally.  Defaults to Primary.
          group = field(:group_name).to_s.strip.presence || Constants::DEFAULT_STOCK_GROUP
          add_simple_node(xml, "PARENT", group)

          # Alias / SKU — Calibrate: ALIAS vs SKUCODE tag varies by Tally version
          add_simple_node(xml, "ALIAS", alias_name) if alias_name.present?

          add_simple_node(xml, "BASEUNITS", uom_name)

          addition_mode = field(:opening_stock).present? ? "As Voucher" : "Not Applicable"
          xml.ADDLALLOCTYPE(addition_mode)

          add_gst_details(xml)
          add_opening_stock_nodes(xml)
        end

        # GST detail section for a stock item in Tally.
        #
        # Calibration notes:
        # - GSTAPPLICABLE: @@APPLICABLE is the Tally formula for applicable.
        # - GSTTYPEOFSUPPLY: "Goods" or "Services"
        # - Exact child tag structure inside GSTDETAILS.LIST varies by Tally version.
        #   Verify against your Tally Prime import specification.
        def add_gst_details(xml)
          return unless hsn_code.present? || gst_rate.present?

          add_simple_node(xml, "HSNCODE", hsn_code) if hsn_code.present?

          # Calibrate: GSTAPPLICABLE value may be "@@APPLICABLE", "Yes", or omitted
          xml.GSTAPPLICABLE("@@APPLICABLE")

          # Calibrate: "Goods" for physical products, "Services" for service items
          supply_type = field(:supply_type).to_s.strip.presence || "Goods"
          xml.GSTTYPEOFSUPPLY(supply_type)

          return unless gst_rate.present?

          # Tally Prime GST detail list for a stock item.
          # Calibrate: this structure is the most version-sensitive part.
          xml.send(:"GSTDETAILS.LIST") do
            xml.APPLICABLEFROM("20170701") # GST effective date — calibrate if needed
            xml.CALCULATIONTYPE("On Value")
            xml.HSNCODE(hsn_code)          if hsn_code.present?
            xml.TAXABILITY("Taxable")

            # Integrated tax rate (IGST) = full GST rate
            xml.INTEGRATEDTAX(format_amount(gst_rate))

            # CGST / SGST: half of IGST unless explicitly provided
            half_rate = cgst_rate || (BigDecimal(gst_rate.to_s) / 2).to_s("F")
            xml.CENTRALTAX(format_amount(half_rate))
            xml.STATECESSES(format_amount(sgst_rate || half_rate))
          end
        end

        # Opening stock entry — omit when zero.
        # Calibrate: some Tally setups require a voucher for opening stock instead.
        def add_opening_stock_nodes(xml)
          qty   = field(:opening_stock)
          value = field(:opening_value)
          return unless qty.present? && BigDecimal(qty.to_s) > 0

          xml.send(:"BATCHALLOCATIONS.LIST") do
            xml.GODOWNNAME("Main Location")
            xml.BATCHNAME("Primary Batch")
            xml.OPENINGBALANCE(format_amount(qty))
            xml.OPENINGVALUE(format_amount(value || 0))
          end
        end
      end
    end
  end
end
