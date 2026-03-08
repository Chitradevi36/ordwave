module Accounting
  module Canonical
    # Maps a PurchaseInvoice (with lines) to a canonical PurchaseVoucher.
    #
    # OMS PurchaseInvoice fields used:
    #   invoice_number          -> voucher_number / supplier_invoice_number
    #   invoice_date            -> voucher_date
    #   supplier.name           -> supplier_ledger_name
    #   total_amount / tax_amount / grand_total -> voucher totals
    #   reverse_charge          -> boolean flag (stored as column if present)
    #   lines (PurchaseInvoiceLine[]) -> inventory_lines
    #
    # PurchaseInvoiceLine fields:
    #   product, qty, unit_price, discount_pct, tax_rate, tax_amount, line_total
    #   effective_hsn_sac_code -> hsn code
    class PurchaseInvoiceToVoucherMapper < BaseMapper
      def call
        pi = record

        voucher_number = require_present!(
          fetch_first_present(pi, :invoice_number, :number, :code),
          "purchase invoice voucher_number"
        )

        supplier_name = require_present!(
          resolve_supplier_name(pi),
          "purchase invoice supplier name"
        )

        tax_summary = compute_tax_summary(pi)
        inv_lines   = map_inventory_lines(pi)
        tax_entries = build_voucher_tax_entries(tax_summary)

        # total_amount on PurchaseInvoice = subtotal (pre-tax); grand_total includes taxes
        subtotal    = decimal!(fetch_first_present(pi, :total_amount, :subtotal))
        grand_total = decimal!(fetch_first_present(pi, :grand_total, :total))

        PurchaseVoucher.new(
          voucher_type:             "purchase",
          voucher_number:           voucher_number,
          voucher_date:             fetch_first_present(pi, :invoice_date, :date),
          supplier_ledger_name:     supplier_name,
          supplier_invoice_number:  voucher_number,
          reverse_charge:           boolean_value(pi.try(:reverse_charge)) || false,
          narration:                build_narration(pi, supplier_name, voucher_number),
          subtotal:                 subtotal,
          discount_total:           decimal(pi.try(:discount_total)),
          taxable_total:            subtotal,
          cgst_total:               decimal!(tax_summary[:cgst]),
          sgst_total:               decimal!(tax_summary[:sgst]),
          igst_total:               decimal!(tax_summary[:igst]),
          cess_total:               BigDecimal("0"),
          round_off_amount:         decimal(pi.try(:round_off_amount)),
          grand_total:              grand_total,
          inventory_lines:          inv_lines,
          tax_entries:              tax_entries,
          metadata:                 build_metadata(
            source_type:      "PurchaseInvoice",
            source_id:        pi.id,
            organization_id:  pi.try(:organization_id),
            invoice_number:   voucher_number,
            supplier_id:      pi.try(:supplier_id)
          )
        )
      end

      private

      def resolve_supplier_name(pi)
        supplier = fetch_first_present(pi, :supplier, :vendor, :party)
        return nil unless supplier
        fetch_first_present(supplier, :name, :business_name)
      end

      def build_narration(pi, supplier_name, voucher_number)
        explicit = string_value(fetch_first_present(pi, :notes, :remarks, :narration))
        return explicit if explicit.present?
        "Purchase Invoice #{voucher_number} from #{supplier_name}".strip
      end

      def compute_tax_summary(pi)
        # PurchaseInvoice stores :tax_amount (combined) at header level.
        # Lines have :tax_rate / :tax_amount but no split CGST/SGST/IGST columns.
        # We aggregate from lines, deriving split amounts the same way as sales.
        lines = resolve_lines(pi)

        cgst = decimal!(lines.sum { |l| decimal!(l.try(:cgst_amount)) })
        sgst = decimal!(lines.sum { |l| decimal!(l.try(:sgst_amount)) })
        igst = decimal!(lines.sum { |l| decimal!(l.try(:igst_amount)) })

        if cgst.zero? && sgst.zero? && igst.zero?
          # No split columns — fall back to header tax_amount, split intra-state
          total_tax = decimal!(fetch_first_present(pi, :tax_amount))
          if total_tax.positive?
            cgst = (total_tax / 2).round(2)
            sgst = total_tax - cgst
          end
        end

        { cgst: cgst, sgst: sgst, igst: igst }
      end

      def resolve_lines(pi)
        fetch_first_present(pi, :lines, :purchase_invoice_lines, :items) || []
      end

      def map_inventory_lines(pi)
        resolve_lines(pi).map { |line| map_single_line(line) }
      end

      def map_single_line(line)
        product  = line.try(:product)
        # PurchaseInvoiceLine uses :tax_rate (not :gst_rate)
        tax_rate = decimal!(fetch_first_present(line, :tax_rate, :gst_rate))
        half_rate = (tax_rate / 2).round(2)

        tax_amt  = decimal!(line.try(:tax_amount))
        cgst_amt = decimal(line.try(:cgst_amount)) || (tax_amt / 2).round(2)
        sgst_amt = decimal(line.try(:sgst_amount)) || (tax_amt - cgst_amt)
        igst_amt = decimal!(line.try(:igst_amount))

        # effective_hsn_sac_code resolves the best available HSN record
        hsn_obj  = line.try(:effective_hsn_sac_code) || product&.try(:hsn_sac_code)
        hsn_code = string_value(hsn_obj&.try(:code) || product&.try(:hsn_code))

        subtotal_line = decimal!(line.try(:subtotal).presence || compute_subtotal(line))

        InventoryLine.new(
          item_name:       string_value(product&.try(:name) || line.try(:item_name)),
          sku:             string_value(product&.try(:sku)),
          item_code:       string_value(product&.try(:sku)),
          hsn_code:        hsn_code,
          quantity:        decimal!(line.try(:qty) || line.try(:quantity)),
          uom:             nil,
          rate:            decimal!(line.try(:unit_price) || line.try(:rate)),
          gross_amount:    gross_from_line(line),
          discount_amount: discount_from_line(line),
          taxable_amount:  subtotal_line,
          gst_rate:        tax_rate,
          cgst_rate:       half_rate,
          sgst_rate:       half_rate,
          igst_rate:       tax_rate,
          cess_rate:       BigDecimal("0"),
          cgst_amount:     cgst_amt,
          sgst_amount:     sgst_amt,
          igst_amount:     igst_amt,
          cess_amount:     BigDecimal("0"),
          total_amount:    decimal!(line.try(:line_total) || line.try(:total_amount)),
          tax_entries:     []
        )
      end

      def gross_from_line(line)
        qty   = decimal!(line.try(:qty) || line.try(:quantity))
        price = decimal!(line.try(:unit_price) || line.try(:rate))
        (qty * price).round(2)
      end

      def discount_from_line(line)
        pct   = decimal!(line.try(:discount_pct) || 0)
        gross = gross_from_line(line)
        (gross * pct / 100).round(2)
      end

      def compute_subtotal(line)
        gross    = gross_from_line(line)
        discount = discount_from_line(line)
        (gross - discount).round(2)
      end

      def build_voucher_tax_entries(tax_summary)
        entries = []
        if tax_summary[:igst].positive?
          entries << TaxEntry.new(tax_type: "igst", rate: nil, amount: tax_summary[:igst],
                                  ledger_kind: "input_tax", label: "IGST")
        else
          entries << TaxEntry.new(tax_type: "cgst", rate: nil, amount: tax_summary[:cgst],
                                  ledger_kind: "input_tax", label: "CGST") if tax_summary[:cgst].positive?
          entries << TaxEntry.new(tax_type: "sgst", rate: nil, amount: tax_summary[:sgst],
                                  ledger_kind: "input_tax", label: "SGST") if tax_summary[:sgst].positive?
        end
        entries
      end
    end
  end
end
