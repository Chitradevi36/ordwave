# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally Sales voucher import XML fragment from a canonical SalesVoucher.
      #
      # Amount/sign convention (Tally Prime standard):
      #   Party ledger  (Dr)  — ISDEEMEDPOSITIVE=Yes, AMOUNT = -grand_total
      #   Sales ledger  (Cr)  — ISDEEMEDPOSITIVE=No,  AMOUNT = +subtotal
      #   Tax ledgers   (Cr)  — ISDEEMEDPOSITIVE=No,  AMOUNT = +tax_amount
      #   Inventory entries   — ISDEEMEDPOSITIVE=No,  AMOUNT = +line_total (goods out)
      #
      # Calibration: these sign conventions are the most common in Tally Prime.
      # Validate with a live export from your Tally company before going to prod.
      class SalesVoucherXmlBuilder < BaseXmlBuilder
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
          Constants::VOUCHER_TYPE_SALES
        end

        def voucher_number
          field(:voucher_number).to_s.strip
        end

        def voucher_date
          format_date(field(:voucher_date) || field(:invoice_date))
        end

        def party_ledger_name
          sanitize_name(field(:party_ledger_name).to_s)
        end

        def sales_ledger_name
          n = field(:sales_ledger_name).to_s.strip
          n.present? ? sanitize_name(n) : resolve_name("sales")
        end

        def grand_total
          field(:grand_total)
        end

        def subtotal
          field(:subtotal) || field(:taxable_total)
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

        # -----------------------------------------------------------------------
        protected
        # -----------------------------------------------------------------------

        def build_voucher_message(xml)
          add_header_nodes(xml)
          add_party_node(xml)
          add_narration_node(xml)
          add_inventory_entries(xml)
          add_voucher_ledger_entries(xml)
          add_voucher_tax_entries(xml)
          add_round_off_entry(xml)
        end

        # Core voucher identification fields.
        def add_header_nodes(xml)
          xml.DATE(voucher_date)
          xml.VOUCHERTYPENAME(voucher_type_name)
          add_simple_node(xml, "VOUCHERNUMBER", voucher_number)
          add_simple_node(xml, "PARTYLEDGERNAME", party_ledger_name)

          # Reference number (used for bill-by-bill reconciliation in Tally)
          add_simple_node(xml, "REFERENCE", voucher_number)
        end

        # Party ledger entry: Dr side.
        # ISDEEMEDPOSITIVE=Yes, AMOUNT = -grand_total
        def add_party_node(xml)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(party_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_YES)
            xml.AMOUNT(format_amount_negative(grand_total))
            # Bill-by-bill reference for reconciliation.
            # Calibrate: BILLALLOCATIONS.LIST tag structure if needed.
            xml.send(:"BILLALLOCATIONS.LIST") do
              xml.NAME(voucher_number)
              xml.BILLTYPE("New Ref")
              xml.AMOUNT(format_amount_negative(grand_total))
            end
          end
        end

        def add_narration_node(xml)
          add_simple_node(xml, "NARRATION", narration, allow_blank: true)
        end

        # Inventory line entries (stock items going out).
        def add_inventory_entries(xml)
          inventory_lines.each { |line| add_inventory_entry(xml, line) }
        end

        # Builds one INVENTORYENTRIES.LIST node for a single canonical InventoryLine.
        #
        # Calibration: RATE format "100/Nos" — adjust if Tally expects only numeric.
        def add_inventory_entry(xml, line)
          item_name   = read_line(line, :item_name)
          qty         = read_line(line, :qty)
          unit        = read_line(line, :unit) || "Nos"
          unit_price  = read_line(line, :unit_price)
          line_total  = read_line(line, :line_total) || read_line(line, :taxable_value)
          line_tax_entries = Array(read_line(line, :tax_entries))

          return if item_name.blank?

          xml.send(:"INVENTORYENTRIES.LIST") do
            xml.STOCKITEMNAME(sanitize_name(item_name))
            xml.ISDEEMEDPOSITIVE(TALLY_NO) # goods going out from inventory
            xml.RATE("#{format_amount(unit_price)}/#{unit}")
            xml.AMOUNT(format_amount(line_total))
            xml.ACTUALQTY("#{format_amount(qty)} #{unit}")
            xml.BILLEDQTY("#{format_amount(qty)} #{unit}")

            # Accounting allocation for this line's base value.
            xml.send(:"ACCOUNTINGALLOCATIONS.LIST") do
              xml.LEDGERNAME(sales_ledger_name)
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(line_total))
            end

            # Line-level tax entries if present (per-line GST detail).
            # Calibrate: Tally may prefer voucher-level tax aggregation.
            add_line_tax_entries(xml, line_tax_entries) if line_tax_entries.any?
          end
        end

        # Sales account Cr entry (voucher-level subtotal).
        def add_voucher_ledger_entries(xml)
          return if subtotal.nil?

          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(sales_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_NO)
            xml.AMOUNT(format_amount(subtotal))
          end
        end

        # Voucher-level tax ledger Cr entries (CGST / SGST / IGST).
        def add_voucher_tax_entries(xml)
          tax_entries.each do |entry|
            ledger_kind = read_from_entry(entry, :ledger_kind) || read_from_entry(entry, :tax_type) || ""
            amount      = read_from_entry(entry, :amount)
            label       = read_from_entry(entry, :label)
            ledger_name = label.presence || resolve_name(ledger_kind)

            next if ledger_name.blank? || amount.nil?

            xml.send(:"ALLLEDGERENTRIES.LIST") do
              xml.LEDGERNAME(sanitize_name(ledger_name))
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(amount)) # positive for Cr
            end
          end
        end

        # Round-off ledger Cr entry if present.
        def add_round_off_entry(xml)
          roa = round_off_amount
          return if roa.nil? || BigDecimal(roa.to_s).zero?

          roa_bd = BigDecimal(roa.to_s)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(resolve_name("round_off"))
            # Round-off can be Dr or Cr depending on sign
            if roa_bd > 0
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(roa_bd.abs))
            else
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(roa_bd.abs))
            end
          end
        end

        # Per-line tax entries embedded in inventory entry — used only when
        # canonical data carries line-level tax breakdown.
        def add_line_tax_entries(xml, line_tax_entries)
          line_tax_entries.each do |entry|
            kind   = read_from_entry(entry, :ledger_kind) || read_from_entry(entry, :tax_type) || ""
            amount = read_from_entry(entry, :amount)
            name   = read_from_entry(entry, :label).presence || resolve_name(kind)
            next if name.blank? || amount.nil?

            # Calibrate: TAXOBJALLOCATIONS.LIST may be required vs ACCOUNTINGALLOCATIONS.LIST
            xml.send(:"ACCOUNTINGALLOCATIONS.LIST") do
              xml.LEDGERNAME(sanitize_name(name))
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(amount))
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
      end
    end
  end
end
