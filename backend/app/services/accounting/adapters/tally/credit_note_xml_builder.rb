# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally Credit Note voucher import XML fragment from a canonical
      # CreditNoteVoucher.
      #
      # A credit note reverses a previous sales invoice — goods returned or
      # allowance given to the customer.
      #
      # Amount/sign convention (Tally Prime standard — reverse of Sales):
      #   Party ledger  (Cr) — ISDEEMEDPOSITIVE=No,  AMOUNT = +grand_total
      #   Sales Returns (Dr) — ISDEEMEDPOSITIVE=Yes, AMOUNT = -subtotal
      #   Tax reversals (Dr) — ISDEEMEDPOSITIVE=Yes, AMOUNT = -tax_amount
      #   Inventory lines    — ISDEEMEDPOSITIVE=Yes (goods coming back in)
      #
      # Calibration: in some Tally configurations the voucher type name must be
      # "Debit Note" on the supplier side.  "Credit Note" is correct for customer
      # returns.  Verify with your Tally setup.
      class CreditNoteXmlBuilder < BaseXmlBuilder
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
          Constants::VOUCHER_TYPE_CREDIT_NOTE
        end

        def voucher_number
          field(:voucher_number).to_s.strip
        end

        def voucher_date
          format_date(field(:voucher_date))
        end

        def party_ledger_name
          sanitize_name(field(:party_ledger_name).to_s)
        end

        def sales_ledger_name
          n = field(:sales_ledger_name).to_s.strip
          n.present? ? sanitize_name(n) : resolve_name("sales")
        end

        def original_invoice_number
          field(:original_invoice_number).to_s.strip
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
          add_sales_return_entry(xml)
          add_tax_reversal_entries(xml)
          add_round_off_entry(xml)
        end

        def add_header_nodes(xml)
          xml.DATE(voucher_date)
          xml.VOUCHERTYPENAME(voucher_type_name)
          add_simple_node(xml, "VOUCHERNUMBER", voucher_number)
          add_simple_node(xml, "PARTYLEDGERNAME", party_ledger_name)

          # Link back to the original sales invoice.
          # Calibrate: ORIGINALVCHTYPE and ORIGINALVCHNO are Tally Prime tags.
          if original_invoice_number.present?
            xml.ORIGINALVCHTYPE(Constants::VOUCHER_TYPE_SALES)
            xml.ORIGINALVCHNO(original_invoice_number)
          end
        end

        # Party Cr — the customer's ledger is being credited (goods returned).
        # ISDEEMEDPOSITIVE=No, amount POSITIVE.
        def add_party_node(xml)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(party_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_NO)
            xml.AMOUNT(format_amount(grand_total))

            # Against-reference bill allocation to clear the original invoice.
            if original_invoice_number.present?
              xml.send(:"BILLALLOCATIONS.LIST") do
                xml.NAME(original_invoice_number)
                xml.BILLTYPE("Agst Ref")
                xml.AMOUNT(format_amount(grand_total))
              end
            end
          end
        end

        def add_narration_node(xml)
          add_simple_node(xml, "NARRATION", narration, allow_blank: true)
        end

        # Inventory entries — goods coming back in (ISDEEMEDPOSITIVE=Yes).
        def add_inventory_entries(xml)
          inventory_lines.each { |line| add_inventory_entry(xml, line) }
        end

        def add_inventory_entry(xml, line)
          item_name  = read_line(line, :item_name)
          qty        = read_line(line, :qty)
          unit       = read_line(line, :unit) || "Nos"
          unit_price = read_line(line, :unit_price)
          line_total = read_line(line, :line_total) || read_line(line, :taxable_value)

          return if item_name.blank?

          xml.send(:"INVENTORYENTRIES.LIST") do
            xml.STOCKITEMNAME(sanitize_name(item_name))
            xml.ISDEEMEDPOSITIVE(TALLY_YES) # goods coming back into inventory
            xml.RATE("#{format_amount(unit_price)}/#{unit}")
            xml.AMOUNT(format_amount_negative(line_total)) # negative for goods in
            xml.ACTUALQTY("#{format_amount(qty)} #{unit}")
            xml.BILLEDQTY("#{format_amount(qty)} #{unit}")

            xml.send(:"ACCOUNTINGALLOCATIONS.LIST") do
              xml.LEDGERNAME(sales_ledger_name)
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(line_total))
            end
          end
        end

        # Sales Returns Dr entry (reversal of the original sales Cr).
        # ISDEEMEDPOSITIVE=Yes, amount NEGATIVE.
        def add_sales_return_entry(xml)
          return if subtotal.nil?

          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(sales_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_YES)
            xml.AMOUNT(format_amount_negative(subtotal))
          end
        end

        # Tax reversal Dr entries (each CGSt/SGST/IGST being reversed).
        # ISDEEMEDPOSITIVE=Yes, amount NEGATIVE.
        def add_tax_reversal_entries(xml)
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
              xml.ISDEEMEDPOSITIVE(TALLY_YES)
              xml.AMOUNT(format_amount_negative(roa_bd.abs))
            else
              xml.ISDEEMEDPOSITIVE(TALLY_NO)
              xml.AMOUNT(format_amount(roa_bd.abs))
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
