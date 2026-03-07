module Invoice
  # Generates a PDF for an issued SalesInvoice using Prawn.
  #
  # Stores the PDF via ActiveStorage and records a `invoice_pdf_generated` audit entry.
  #
  # Usage:
  #   result = Invoice::PdfRendererService.call(actor: user, invoice: invoice)
  #   result.success?     # true
  #   result.download_url # signed ActiveStorage URL
  #
  class PdfRendererService
    require 'prawn'
    require 'prawn/table'

    Result = Struct.new(:success?, :download_url, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, invoice:)
      @actor   = actor
      @invoice = invoice
    end

    def call
      unless @invoice.issued?
        return Result.new(
          success?: false,
          download_url: nil,
          errors: ["PDF can only be generated for issued invoices (current: #{@invoice.status})"]
        )
      end

      pdf_io = generate_pdf
      attach_pdf(pdf_io)
      write_audit!
      url = download_url

      Result.new(success?: true, download_url: url, errors: [])
    rescue => e
      Rails.logger.error("[Invoice::PdfRendererService] #{e.class}: #{e.message}")
      Result.new(success?: false, download_url: nil, errors: [e.message])
    end

    private

    def generate_pdf
      inv    = @invoice
      org    = inv.organization
      branch = inv.branch
      cust   = inv.customer

      pdf = Prawn::Document.new(
        page_size: 'A4',
        margin:    [30, 40, 30, 40],
        info: {
          Title:    inv.invoice_number,
          Author:   org.name,
          Creator:  'OmniDist OMS'
        }
      )

      # ── Header ─────────────────────────────────────────────────────────
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
        pdf.text org.name, size: 18, style: :bold
        pdf.text "GSTIN: #{org.gst_number}" if org.gst_number.present?
        pdf.text [org.address, org.city, org.state].compact.join(', ') if org.address.present?
        pdf.move_down 4
        pdf.text "Branch: #{branch.name} (#{branch.code})", size: 9, color: '444444'
      end

      pdf.move_down 8

      pdf.fill_color '1a56db'
      pdf.fill_rectangle [0, pdf.cursor + 2], pdf.bounds.width, 20
      pdf.fill_color 'FFFFFF'
      pdf.text_box "TAX INVOICE",
                   at: [0, pdf.cursor],
                   width: pdf.bounds.width,
                   align: :center,
                   size: 12,
                   style: :bold
      pdf.fill_color '000000'
      pdf.move_down 22

      # ── Invoice meta ────────────────────────────────────────────────────
      meta_left = [
        ["Invoice #",   inv.invoice_number],
        ["Date",        inv.invoice_date.strftime('%d %b %Y')],
        ["Due Date",    inv.due_date ? inv.due_date.strftime('%d %b %Y') : 'N/A'],
        ["Status",      inv.status.upcase]
      ]
      meta_right = [
        ["Customer",    cust.name],
        ["GSTIN",       cust.gstin.presence || 'Unregistered'],
        ["Code",        cust.code],
        ["Branch",      branch.name]
      ]

      pdf.table(meta_left.zip(meta_right).map(&:flatten),
        cell_style: { border_width: 0, size: 9 },
        width: pdf.bounds.width
      ) do |t|
        t.columns(0).font_style = :bold
        t.columns(2).font_style = :bold
      end

      pdf.move_down 8
      pdf.stroke_horizontal_rule
      pdf.move_down 8

      # ── Lines Table ──────────────────────────────────────────────────────
      line_header = ['#', 'Product', 'HSN', 'Qty', 'Rate', 'Disc%', 'Taxable', 'GST%', 'Tax', 'Total']
      line_rows   = inv.lines.includes(:product).map.with_index(1) do |l, i|
        [
          i,
          l.product.name,
          l.hsn_code.to_s,
          l.qty.to_s('F').sub(/\.?0+$/, ''),
          format_currency(l.unit_price),
          "#{l.discount_pct.to_f}%",
          format_currency(l.taxable_value),
          "#{l.gst_rate.to_f}%",
          format_currency(l.tax_amount),
          format_currency(l.line_total)
        ]
      end

      table_data = [line_header] + line_rows
      pdf.table(table_data, width: pdf.bounds.width, header: true) do |t|
        t.row(0).font_style         = :bold
        t.row(0).background_color   = 'EBF5FB'
        t.columns(3..9).align       = :right
        t.column(0).width           = 20
        t.cell_style = { size: 8, padding: [3, 4] }
      end

      pdf.move_down 10

      # ── Totals Block ─────────────────────────────────────────────────────
      bk = inv.tax_breakup
      totals = [
        ['Subtotal (Taxable)',  format_currency(inv.subtotal)],
        ['CGST',               format_currency(bk[:cgst_total])],
        ['SGST',               format_currency(bk[:sgst_total])],
        ['IGST',               format_currency(bk[:igst_total])],
        ['Total Tax',          format_currency(inv.tax_total)],
        ['Grand Total',        format_currency(inv.grand_total)]
      ]

      totals_x = pdf.bounds.width - 180
      pdf.bounding_box([totals_x, pdf.cursor], width: 180) do
        pdf.table(totals, width: 180) do |t|
          t.column(1).align = :right
          t.row(-1).font_style       = :bold
          t.row(-1).background_color = 'EBF5FB'
          t.cell_style = { size: 9, padding: [3, 4] }
        end
      end

      pdf.move_down 20

      # ── HSN Summary ──────────────────────────────────────────────────────
      if bk[:hsn_summary].any?
        pdf.text 'HSN / SAC Summary', size: 9, style: :bold
        pdf.move_down 4
        hsn_header = ['HSN Code', 'Taxable Value', 'GST Rate', 'Tax Amount']
        hsn_rows = bk[:hsn_summary].map do |code, data|
          [code.to_s, format_currency(data[:taxable_value]), "#{data[:gst_rate]}%", format_currency(data[:tax_amount])]
        end
        pdf.table([hsn_header] + hsn_rows, width: pdf.bounds.width) do |t|
          t.row(0).font_style       = :bold
          t.row(0).background_color = 'EBF5FB'
          t.columns(1..3).align     = :right
          t.cell_style = { size: 8, padding: [2, 4] }
        end
      end

      pdf.move_down 14
      pdf.text 'This is a computer-generated invoice and does not require a physical signature.',
               size: 7, color: '888888', align: :center

      StringIO.new(pdf.render)
    end

    def attach_pdf(pdf_io)
      filename = "#{@invoice.invoice_number}.pdf"
      @invoice.pdf_document.attach(
        io:           pdf_io,
        filename:     filename,
        content_type: 'application/pdf'
      )
      @invoice.update_columns(pdf_generated_at: Time.current)
    end

    def download_url
      return nil unless @invoice.pdf_document.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        @invoice.pdf_document,
        expires_in: 1.hour,
        disposition: 'inline'
      )
    rescue => _e
      # Fallback: return the storage service URL
      @invoice.pdf_document.url
    end

    def write_audit!
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @invoice.organization,
        auditable:    @invoice,
        action:       'invoice_pdf_generated',
        changes: {
          invoice_number:   @invoice.invoice_number,
          pdf_generated_at: @invoice.pdf_generated_at
        }
      )
    end

    def format_currency(amount)
      "Rs #{format('%.2f', amount.to_d)}"
    end
  end
end
