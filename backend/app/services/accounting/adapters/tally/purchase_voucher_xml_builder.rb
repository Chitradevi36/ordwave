# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally Purchase voucher import XML fragment from a canonical
      # PurchaseVoucher.
      #
      # A purchase voucher records a supplier invoice (goods/services received).
      #
      # Amount/sign convention (Tally Prime standard):
      #   Supplier ledger  (Cr) — ISDEEMEDPOSITIVE=No,  AMOUNT = +grand_total
      #   Purchase ledger  (Dr) — ISDEEMEDPOSITIVE=Yes, AMOUNT = -subtotal
      #   Input tax (Dr)        — ISDEEMEDPOSITIVE=Yes, AMOUNT = -tax_amount
      #   Inventory lines       — ISDEEMEDPOSITIVE=Yes (goods coming into stock)
      #
      # Calibration notes are inline.  Input tax tag structure is the most
      # likely element to need adjustment per Tally GST configuration.
      class PurchaseVoucherXmlBuilder < BaseXmlBuilder
        def export_kind = :voucher
        def report_name = XmlHelper::REPORT_VOUCHERS

        # -----------------------------------------------------------------------
        # Template method
        # -----------------------------------------------------------------------

        def build_message(xml)
          xml.VOUCHER(
            VCHTYPE: voucher_type_name,
            ACTION:  XmlHelper::ACTION_CREATE
          ) do
            build_voucher_message(xml)
          end
        end

        # -----------------------------------------------------------------------
        # Named helpers
        # -----------------------------------------------------------------------

        def voucher_type_name
          Constants::VOUCHER_TYPE_PURCHASE
        end

        def voucher_number
          field(:voucher_number).to_s.strip
        end

        def voucher_date
          format_date(field(:voucher_date) || field(:invoice_date))
        end

        # The OMS supplier invoice reference number (printed on supplier's invoice).
        def supplier_invoice_number
          field(:supplier_invoice_number).to_s.strip
        end

        def supplier_ledger_name
          sanitize_name(field(:supplier_ledger_name).to_s)
        end

        def purchase_ledger_name
          n = field(:purchase_ledger_name).to_s.strip
          n.present? ? sanitize_name(n) : resolve_name("purchase")
        end

        def grand_total
          field(:grand_total)
        end

        def subtotal
          field(:subtotal) || field(:taxable_total) || field(:total_amount)
        end

        def tax_entries
          Array(field(:tax_entries))
        end

        def inventory_lines
          Array(field(:inventory_lines))
        end

        def narration
          field(:narration).to_s.strip
        end

        def round_off_amount
          field(:round_off_amount)
        end

        # Whether this is a reverse charge transaction (GST on imports etc.).
        def reverse_charge?
          val = field(:reverse_charge)
          val == true || val.to_s.casecmp("true").zero?
        end

        # -----------------------------------------------------------------------
        protected
        # -----------------------------------------------------------------------

        def build_voucher_message(xml)
          add_header_nodes(xml)
          add_supplier_node(xml)
          add_narration_node(xml)
          add_inventory_entries(xml)
          add_purchase_ledger_entry(xml)
          add_input_tax_entries(xml)
          add_round_off_entry(xml)
        end

        def add_header_nodes(xml)
          xml.DATE(voucher_date)
          xml.VOUCHERTYPENAME(voucher_type_name)
          add_simple_node(xml, "VOUCHERNUMBER",    voucher_number)
          add_simple_node(xml, "PARTYLEDGERNAME",  supplier_ledger_name)

          # Supplier's own invoice number goes in the reference / order fields.
          # Calibrate: BILLNAME vs REFERENCE vs ORDERNUMBER tag for your version.
          add_simple_node(xml, "REFERENCE", supplier_invoice_number) if supplier_invoice_number.present?

          # Reverse charge flag.
          # Calibrate: ISREVERSECHARGEAPPLICABLE is Tally Prime; earlier versions differ.
          if reverse_charge?
            xml.ISREVERSECHARGEAPPLICABLE(TALLY_YES)
          end
        end

        # Supplier ledger Cr entry.
        # ISDEEMEDPOSITIVE=No, amount POSITIVE (supplier becomes creditor).
        def add_supplier_node(xml)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(supplier_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_NO)
            xml.AMOUNT(format_amount(grand_total))

            # Bill reference for bill-by-bill tracking.
            ref_name = supplier_invoice_number.presence || voucher_number
            xml.send(:"BILLALLOCATIONS.LIST") do
              xml.NAME(sanitize_name(ref_name))
              xml.BILLTYPE("New Ref")
              xml.AMOUNT(format_amount(grand_total))
            end
          end
        end

        def add_narration_node(xml)
          add_simple_node(xml, "NARRATION", narration, allow_blank: true)
        end

        # Inventory entries — goods arriving into stock (ISDEEMEDPOSITIVE=Yes).
        def add_inventory_entries(xml)
          inventory_lines.each { |line| add_inventory_entry(xml, line) }
        end

        def add_inventory_entry(xml, line)
          item_name   = read_line(line, :item_name)
          qty         = read_line(line, :qty)
          unit        = read_line(line, :unit) || "Nos"
          unit_price  = read_line(line, :unit_price)
          line_total  = read_line(line, :line_total) || read_line(line, :taxable_value)
          hsn         = effective_hsn(line)

          return if item_name.blank?

          xml.send(:"INVENTORYENTRIES.LIST") do
            xml.STOCKITEMNAME(sanitize_name(item_name))
            xml.ISDEEMEDPOSITIVE(TALLY_YES) # goods coming in
            xml.RATE("#{format_amount(unit_price)}/#{unit}")
            xml.AMOUNT(format_amount_negative(line_total)) # negative for Dr stock
            xml.ACTUALQTY("#{format_amount(qty)} #{unit}")
            xml.BILLEDQTY("#{format_amount(qty)} #{unit}")

            # HSN code at line level if present.
            # Calibrate: HSNCODE vs HSNDETAILS tag structure.
            add_simple_node(xml, "HSNCODE", hsn) if hsn.present?

            xml.send(:"ACCOUNTINGALLOCATIONS.LIST") do
              xml.LEDGERNAME(purchase_ledger_name)
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(line_total))
            end
          end
        end

        # Purchase account Dr entry (base taxable amount).
        # ISDEEMEDPOSITIVE=Yes, amount NEGATIVE.
        def add_purchase_ledger_entry(xml)
          return if subtotal.nil?

          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(purchase_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_YES)
            xml.AMOUNT(format_amount_negative(subtotal))
          end
        end

        # Input tax (CGST/SGST/IGST) Dr entries.
        # ISDEEMEDPOSITIVE=Yes, amounts NEGATIVE.
        #
        # Calibration: for reverse charge scenarios, the input tax ledger names
        # may differ (e.g. "CGST on RCM").  Inject via ledger_mapping if needed.
        def add_input_tax_entries(xml)
          tax_entries.each do |entry|
            ledger_kind = read_from_entry(entry, :ledger_kind) || read_from_entry(entry, :tax_type) || ""
            amount      = read_from_entry(entry, :amount)
            label       = read_from_entry(entry, :label)
            ledger_name = label.presence || resolve_name(ledger_kind)

            next if ledger_name.blank? || amount.nil?

            xml.send(:"ALLLEDGERENTRIES.LIST") do
              xml.LEDGERNAME(sanitize_name(ledger_name))
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(amount))
            end
          end
        end

        def add_round_off_entry(xml)
          roa = round_off_amount
          return if roa.nil? || BigDecimal(roa.to_s).zero?

          roa_bd = BigDecimal(roa.to_s)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(resolve_name("round_off"))
            if roa_bd > 0
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(roa_bd.abs))
            else
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(roa_bd.abs))
            end
          end
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        def read_line(line, key)
          sym = key.to_sym
          str = key.to_s
          if line.is_a?(Hash)
            line[sym] || line[str]
          elsif line.respond_to?(sym)
            line.public_send(sym)
          end
        end

        alias read_from_entry read_line

        # Reads the effective HSN/SAC code from a line.
        # Mirrors PurchaseInvoiceLine#effective_hsn_sac_code in the OMS domain.
        def effective_hsn(line)
          read_line(line, :effective_hsn_sac_code) ||
            read_line(line, :hsn_code) ||
            read_line(line, :hsn_sac_code)
        end
      end
    end
  end
end
