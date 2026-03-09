module Accounting
  module Canonical
    # Maps a SalesInvoice (with lines) to a canonical SalesVoucher.
    #
    # OMS fields used:
    #   invoice_number              -> voucher_number
    #   invoice_date                -> voucher_date
    #   customer.name               -> party_ledger_name
    #   subtotal / tax_total / grand_total -> voucher totals
    #   lines (SalesInvoiceLine[])  -> inventory_lines
    #   tax_breakup                 -> aggregated tax_entries
    #
    # Each SalesInvoiceLine has:
    #   product, qty, unit_price, discount_pct,
    #   taxable_value, gst_rate, cgst_amount, sgst_amount, igst_amount,
    #   tax_amount, line_total
    class InvoiceToSalesVoucherMapper < BaseMapper
      def call
        invoice = record

        voucher_number = require_present!(
          fetch_first_present(invoice, :invoice_number, :number, :code),
          "invoice voucher_number"
        )

        party_name = require_present!(
          resolve_party_name(invoice),
          "invoice customer/party name"
        )

        voucher_date    = fetch_first_present(invoice, :invoice_date, :date)
        narration       = build_narration(invoice)
        org_id          = invoice.try(:organization_id)

        # Aggregate tax breakdown from stored line amounts
        tax_summary     = compute_tax_summary(invoice)
        inv_lines       = map_inventory_lines(invoice)
        tax_entries_agg = build_voucher_tax_entries(tax_summary, ledger_kind: "output_tax")

        SalesVoucher.new(
          voucher_type:          "sales",
          voucher_number:        voucher_number,
          voucher_date:          voucher_date,
          party_ledger_name:     party_name,
          place_of_supply_state: resolve_place_of_supply(invoice),
          narration:             narration,
          subtotal:              decimal!(fetch_first_present(invoice, :subtotal)),
          discount_total:        decimal(invoice.try(:discount_total)),
          taxable_total:         decimal!(fetch_first_present(invoice, :subtotal)),
          cgst_total:            decimal!(tax_summary[:cgst]),
          sgst_total:            decimal!(tax_summary[:sgst]),
          igst_total:            decimal!(tax_summary[:igst]),
          cess_total:            decimal(tax_summary[:cess]),
          round_off_amount:      decimal(invoice.try(:round_off_amount)),
          grand_total:           decimal!(fetch_first_present(invoice, :grand_total, :total)),
          inventory_lines:       inv_lines,
          tax_entries:           tax_entries_agg,
          metadata:              build_metadata(
            source_type:     "SalesInvoice",
            source_id:       invoice.id,
            organization_id: org_id,
            invoice_number:  voucher_number
          )
        )
      end

      private

      def resolve_party_name(invoice)
        party = fetch_first_present(invoice, :customer, :retailer, :party)
        return nil unless party
        fetch_first_present(party, :name, :business_name, :legal_name)
      end

      def resolve_place_of_supply(invoice)
        # Try customer billing address state, then branch state
        customer = invoice.try(:customer)
        if customer.respond_to?(:addresses)
          billing = customer.addresses.find { |a| a.try(:label) == "billing" } ||
                    customer.addresses.first
          state = billing&.try(:state)
          return string_value(state) if state.present?
        end
        string_value(invoice.try(:place_of_supply) || invoice.try(:branch)&.try(:state))
      end

      def build_narration(invoice)
        explicit = fetch_first_present(invoice, :notes, :remarks, :narration)
        return string_value(explicit) if explicit.present?

        customer_name = resolve_party_name(invoice)
        "Sales Invoice #{invoice.try(:invoice_number)} — #{customer_name}".strip
      end

      # Returns { cgst: BigDecimal, sgst: BigDecimal, igst: BigDecimal, cess: BigDecimal }
      # Reads from tax_breakup if available; otherwise sums from lines.
      def compute_tax_summary(invoice)
        if invoice.respond_to?(:tax_breakup)
          tb = invoice.tax_breakup
          return {
            cgst: decimal!(tb[:cgst_total]),
            sgst: decimal!(tb[:sgst_total]),
            igst: decimal!(tb[:igst_total]),
            cess: decimal(tb[:cess_total])
          }
        end

        lines = resolve_lines(invoice)
        {
          cgst: decimal!(lines.sum { |l| decimal!(l.try(:cgst_amount)) }),
          sgst: decimal!(lines.sum { |l| decimal!(l.try(:sgst_amount)) }),
          igst: decimal!(lines.sum { |l| decimal!(l.try(:igst_amount)) }),
          cess: decimal(lines.sum  { |l| decimal(l.try(:cess_amount)) })
        }
      end

      def resolve_lines(invoice)
        fetch_first_present(invoice, :lines, :invoice_items, :items, :line_items) || []
      end

      def map_inventory_lines(invoice)
        resolve_lines(invoice).map { |line| map_single_line(line) }
      end

      def map_single_line(line)
        product  = line.try(:product)
        gst_rate = decimal!(line.try(:gst_rate))
        cgst_amt = decimal!(line.try(:cgst_amount))
        sgst_amt = decimal!(line.try(:sgst_amount))
        igst_amt = decimal!(line.try(:igst_amount))
        # If CGST/SGST/IGST not stored separately, derive from tax_amount
        if cgst_amt.zero? && sgst_amt.zero? && igst_amt.zero?
          total_tax = decimal!(line.try(:tax_amount))
          if igst_only?(line)
            igst_amt = total_tax
          else
            cgst_amt = (total_tax / 2).round(2)
            sgst_amt = total_tax - cgst_amt
          end
        end

        half_rate = (gst_rate / 2).round(2)

        line_tax_entries = build_line_tax_entries(
          gst_rate:  gst_rate,
          half_rate: half_rate,
          cgst_amt:  cgst_amt,
          sgst_amt:  sgst_amt,
          igst_amt:  igst_amt,
          cess_rate: decimal(line.try(:cess_rate)),
          cess_amt:  decimal(line.try(:cess_amount))
        )

        InventoryLine.new(
          item_name:       string_value(product.try(:name) || line.try(:item_name)),
          sku:             string_value(product.try(:sku) || line.try(:sku)),
          item_code:       string_value(product.try(:sku)),
          hsn_code:        string_value(product.try(:hsn_code)),
          quantity:        decimal!(line.try(:qty) || line.try(:quantity)),
          uom:             resolve_line_uom(product),
          rate:            decimal!(line.try(:unit_price) || line.try(:rate)),
          gross_amount:    decimal!(line.try(:gross_amount) || gross_from_line(line)),
          discount_amount: decimal(line.try(:discount_amount) || discount_from_line(line)),
          taxable_amount:  decimal!(line.try(:taxable_value) || line.try(:taxable_amount)),
          gst_rate:        gst_rate,
          cgst_rate:       half_rate,
          sgst_rate:       half_rate,
          igst_rate:       gst_rate,
          cess_rate:       decimal(line.try(:cess_rate)),
          cgst_amount:     cgst_amt,
          sgst_amount:     sgst_amt,
          igst_amount:     igst_amt,
          cess_amount:     decimal(line.try(:cess_amount)),
          total_amount:    decimal!(line.try(:line_total) || line.try(:total_amount)),
          tax_entries:     line_tax_entries
        )
      end

      # Determine if line is inter-state (IGST only) vs intra-state (CGST+SGST).
      # Uses stored igst_amount presence as the signal; falls back to false.
      def igst_only?(line)
        decimal(line.try(:igst_amount)).to_d.positive? &&
          decimal(line.try(:cgst_amount)).to_d.zero?
      end

      def gross_from_line(line)
        qty   = decimal!(line.try(:qty) || line.try(:quantity))
        price = decimal!(line.try(:unit_price) || line.try(:rate))
        qty * price
      end

      def discount_from_line(line)
        pct   = decimal!(line.try(:discount_pct) || 0)
        gross = decimal!(gross_from_line(line))
        (gross * pct / 100).round(2)
      end

      def resolve_line_uom(product)
        return nil unless product.respond_to?(:units_of_measure)
        uom = product.try(:units_of_measure)
        string_value(fetch_first_present(uom, :symbol, :short_name, :name))
      end

      def build_line_tax_entries(gst_rate:, half_rate:, cgst_amt:, sgst_amt:, igst_amt:, cess_rate: BigDecimal("0"), cess_amt: BigDecimal("0"))
        entries = []
        if igst_amt.positive?
          entries << TaxEntry.new(
            tax_type: "igst", rate: gst_rate, amount: igst_amt,
            ledger_kind: "output_tax", label: "IGST #{gst_rate}%"
          )
        else
          entries << TaxEntry.new(
            tax_type: "cgst", rate: half_rate, amount: cgst_amt,
            ledger_kind: "output_tax", label: "CGST #{half_rate}%"
          ) if cgst_amt.positive?
          entries << TaxEntry.new(
            tax_type: "sgst", rate: half_rate, amount: sgst_amt,
            ledger_kind: "output_tax", label: "SGST #{half_rate}%"
          ) if sgst_amt.positive?
        end
        if cess_amt.positive?
          entries << TaxEntry.new(
            tax_type: "cess", rate: cess_rate, amount: cess_amt,
            ledger_kind: "output_tax", label: "Cess #{cess_rate}%"
          )
        end
        entries
      end

      def build_voucher_tax_entries(tax_summary, ledger_kind:)
        entries = []
        if tax_summary[:igst].positive?
          entries << TaxEntry.new(
            tax_type: "igst", rate: nil, amount: tax_summary[:igst],
            ledger_kind: ledger_kind, label: "IGST"
          )
        else
          entries << TaxEntry.new(
            tax_type: "cgst", rate: nil, amount: tax_summary[:cgst],
            ledger_kind: ledger_kind, label: "CGST"
          ) if tax_summary[:cgst].positive?
          entries << TaxEntry.new(
            tax_type: "sgst", rate: nil, amount: tax_summary[:sgst],
            ledger_kind: ledger_kind, label: "SGST"
          ) if tax_summary[:sgst].positive?
        end
        if tax_summary[:cess]&.positive?
          entries << TaxEntry.new(
            tax_type: "cess", rate: nil, amount: tax_summary[:cess],
            ledger_kind: ledger_kind, label: "Cess"
          )
        end
        entries
      end
    end
  end
end
