class GenerateInvoiceDocumentJob
  include Sidekiq::Worker
  sidekiq_options retry: 3, dead: true

  # Generate and save invoice document PDF
  #
  # @param sales_invoice_id [Integer] - The SalesInvoice record to generate document for
  # @param force [Boolean] - Force regeneration if document already exists
  def perform(sales_invoice_id, force: false)
    sales_invoice = SalesInvoice.find(sales_invoice_id)
    organization = sales_invoice.organization
    user = sales_invoice.created_by

    Rails.logger.info("[GenerateInvoiceDocumentJob] Processing invoice #{sales_invoice.invoice_number} (ID: #{sales_invoice_id})")

    # Skip if document already exists (unless forced)
    existing_doc = Document.find_by(
      organization_id: organization.id,
      reference_id: sales_invoice.id,
      document_type: 'invoice'
    )

    if existing_doc && !force
      Rails.logger.info("[GenerateInvoiceDocumentJob] Document already exists for invoice #{sales_invoice.invoice_number}")
      return
    end

    # Build invoice data for document generation
    invoice_data = build_invoice_data(sales_invoice)

    begin
      generator = DocumentGeneratorService.new
      document = generator.generate_and_save(
        :invoice,
        invoice_data,
        organization.id,
        {
          reference_id: sales_invoice.id,
          user_id: user.id,
          source_type: 'sales_invoice',
          generation_mode: 'auto',
        }
      )

      Rails.logger.info("[GenerateInvoiceDocumentJob] ✓ Document generated: #{document.id} for invoice #{sales_invoice.invoice_number}")
    rescue => e
      Rails.logger.error("[GenerateInvoiceDocumentJob] ✗ Failed to generate document for invoice #{sales_invoice.invoice_number}: #{e.message}")
      raise e
    end
  end

  private

  def build_invoice_data(sales_invoice)
    {
      invoice_id: sales_invoice.invoice_number,
      amount: sales_invoice.grand_total,

      customer: {
        name: sales_invoice.customer&.name || "Customer",
        code: sales_invoice.customer&.code || "",
        address: sales_invoice.customer&.address || "",
        phone: sales_invoice.customer&.phone || "",
        gstin: sales_invoice.customer&.gstin || "",
      },

      organization: {
        name: sales_invoice.organization&.name || "Organization",
        gstin: sales_invoice.organization&.gstin || "",
        phone: sales_invoice.organization&.phone || "",
        address: sales_invoice.organization&.address || "",
      },

      items: sales_invoice.lines.map do |line|
        {
          description: line.product&.name || "Product",
          qty: line.qty,
          rate: line.unit_price,
          amount: line.line_total,
          gst_rate: line.gst_rate,
          hsn_code: line.hsn_code,
          cgst_rate: line.cgst_rate,
          sgst_rate: line.sgst_rate,
          igst_rate: line.igst_rate,
          tax_amount: line.tax_amount,
        }
      end,

      invoice_date: sales_invoice.invoice_date.strftime("%d-%b-%Y"),
      due_date: sales_invoice.due_date&.strftime("%d-%b-%Y") || "",
      invoice_number_display: sales_invoice.invoice_number,

      subtotal: sales_invoice.subtotal,
      tax_total: sales_invoice.tax_total,
      grand_total: sales_invoice.grand_total,

      terms: "Payment terms: #{sales_invoice.customer&.credit_days || 15} days",
      notes: sales_invoice.notes || "Thank you for your business!",
    }
  end
end
