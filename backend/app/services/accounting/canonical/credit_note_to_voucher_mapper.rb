module Accounting
  module Canonical
    # Maps a CreditNote (with lines) to a canonical CreditNoteVoucher.
    #
    # OMS CreditNote fields used:
    #   credit_note_number  -> voucher_number
    #   created_at/date     -> voucher_date
    #   customer.name       -> party_ledger_name
    #   return_request.sales_order.invoice -> original_invoice_number (best-effort)
    #   subtotal / tax_total / total -> totals
    #   lines (CreditNoteLine[]) -> inventory_lines
    #
    # CreditNoteLine fields:
    #   product, qty, unit_price, gst_rate, tax_amount, line_total
    class CreditNoteToVoucherMapper < BaseMapper
      def call
        cn = record

        voucher_number = require_present!(
          fetch_first_present(cn, :credit_note_number, :number, :code),
          "credit note voucher_number"
        )

        party_name = require_present!(
          resolve_party_name(cn),
          "credit note customer/party name"
        )

        tax_summary = compute_tax_summary(cn)
        inv_lines   = map_inventory_lines(cn)
        tax_entries = build_voucher_tax_entries(tax_summary)

        CreditNoteVoucher.new(
          voucher_type:            "credit_note",
          voucher_number:          voucher_number,
          voucher_date:            fetch_first_present(cn, :issued_at, :credit_note_date, :created_at),
          party_ledger_name:       party_name,
          original_invoice_number: resolve_original_invoice_number(cn),
          narration:               build_narration(cn, party_name, voucher_number),
          subtotal:                decimal!(fetch_first_present(cn, :subtotal)),
          taxable_total:           decimal!(fetch_first_present(cn, :subtotal)),
          cgst_total:              decimal!(tax_summary[:cgst]),
          sgst_total:              decimal!(tax_summary[:sgst]),
          igst_total:              decimal!(tax_summary[:igst]),
          cess_total:              decimal(tax_summary[:cess]),
          grand_total:             decimal!(fetch_first_present(cn, :total, :grand_total, :net_total)),
          inventory_lines:         inv_lines,
          tax_entries:             tax_entries,
          metadata:                build_metadata(
            source_type:          "CreditNote",
            source_id:            cn.id,
            organization_id:      cn.try(:organization_id),
            credit_note_number:   voucher_number
          )
        )
      end

      private

      def resolve_party_name(cn)
        party = fetch_first_present(cn, :customer, :retailer, :party)
        return nil unless party
        fetch_first_present(party, :name, :business_name)
      end

      # Attempt to trace back to the originating invoice number.
      # CreditNote -> return_request -> sales_order (or linked invoice directly).
      def resolve_original_invoice_number(cn)
        # Direct link
        inv = fetch_first_present(cn, :sales_invoice, :original_invoice)
        return string_value(inv.try(:invoice_number)) if inv.present?

        # Via return_request -> linked invoice chain
        return_req = cn.try(:return_request)
        if return_req
          inv = fetch_first_present(return_req, :sales_invoice, :original_invoice)
          return string_value(inv.try(:invoice_number)) if inv.present?
        end

        nil
      end

      def build_narration(cn, party_name, voucher_number)
        explicit = string_value(fetch_first_present(cn, :notes, :remarks, :narration))
        return explicit if explicit.present?
        "Credit Note #{voucher_number} — #{party_name}".strip
      end

      def compute_tax_summary(cn)
        lines = resolve_lines(cn)
        # CreditNoteLine stores only :tax_amount (combined), not split components.
        # Split 50/50 into CGST/SGST only if no explicit split columns present.
        total_tax = decimal!(lines.sum { |l| decimal!(l.try(:tax_amount)) })

        cgst = decimal!(lines.sum { |l| decimal!(l.try(:cgst_amount)) })
        sgst = decimal!(lines.sum { |l| decimal!(l.try(:sgst_amount)) })
        igst = decimal!(lines.sum { |l| decimal!(l.try(:igst_amount)) })
        cess = decimal(lines.sum  { |l| decimal(l.try(:cess_amount)) })

        if cgst.zero? && sgst.zero? && igst.zero? && total_tax.positive?
          # Default to intra-state split (safe fallback; inter-state would be unusual for credit notes)
          cgst = (total_tax / 2).round(2)
          sgst = total_tax - cgst
        end

        { cgst: cgst, sgst: sgst, igst: igst, cess: cess }
      end

      def resolve_lines(cn)
        fetch_first_present(cn, :lines, :credit_note_lines, :items) || []
      end

      def map_inventory_lines(cn)
        resolve_lines(cn).map { |line| map_single_line(line) }
      end

      def map_single_line(line)
        product  = line.try(:product)
        gst_rate = decimal!(line.try(:gst_rate))
        half     = (gst_rate / 2).round(2)
        tax_amt  = decimal!(line.try(:tax_amount))
        cgst_amt = decimal(line.try(:cgst_amount)) || (tax_amt / 2).round(2)
        sgst_amt = decimal(line.try(:sgst_amount)) || (tax_amt - cgst_amt)
        igst_amt = decimal!(line.try(:igst_amount))

        InventoryLine.new(
          item_name:      string_value(product&.try(:name) || line.try(:item_name)),
          sku:            string_value(product&.try(:sku)),
          item_code:      string_value(product&.try(:sku)),
          hsn_code:       string_value(product&.try(:hsn_code)),
          quantity:       decimal!(line.try(:qty) || line.try(:quantity)),
          uom:            nil,
          rate:           decimal!(line.try(:unit_price) || line.try(:rate)),
          gross_amount:   gross_from_line(line),
          discount_amount: BigDecimal("0"),
          taxable_amount: gross_from_line(line),
          gst_rate:       gst_rate,
          cgst_rate:      half,
          sgst_rate:      half,
          igst_rate:      gst_rate,
          cess_rate:      decimal(line.try(:cess_rate)),
          cgst_amount:    cgst_amt,
          sgst_amount:    sgst_amt,
          igst_amount:    igst_amt,
          cess_amount:    decimal(line.try(:cess_amount)),
          total_amount:   decimal!(line.try(:line_total) || line.try(:total_amount)),
          tax_entries:    []
        )
      end

      def gross_from_line(line)
        qty   = decimal!(line.try(:qty) || line.try(:quantity))
        price = decimal!(line.try(:unit_price) || line.try(:rate))
        (qty * price).round(2)
      end

      def build_voucher_tax_entries(tax_summary)
        entries = []
        if tax_summary[:igst].positive?
          entries << TaxEntry.new(tax_type: "igst", rate: nil, amount: tax_summary[:igst],
                                  ledger_kind: "output_tax", label: "IGST")
        else
          entries << TaxEntry.new(tax_type: "cgst", rate: nil, amount: tax_summary[:cgst],
                                  ledger_kind: "output_tax", label: "CGST") if tax_summary[:cgst].positive?
          entries << TaxEntry.new(tax_type: "sgst", rate: nil, amount: tax_summary[:sgst],
                                  ledger_kind: "output_tax", label: "SGST") if tax_summary[:sgst].positive?
        end
        if tax_summary[:cess]&.positive?
          entries << TaxEntry.new(tax_type: "cess", rate: nil, amount: tax_summary[:cess],
                                  ledger_kind: "output_tax", label: "Cess")
        end
        entries
      end
    end
  end
end
