# Generates (or regenerates) a PDF attachment for a given SalesInvoice.
#
# Triggered by:
#   - Invoice creation (auto_on_delivery flow)
#   - Manual user request via POST /api/v1/invoices/:id/pdf
#
# Idempotent: safe to enqueue multiple times — overwrites the existing attachment.
#
class GenerateInvoicePdfJob < ApplicationJob
  queue_as :critical

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  # @param invoice_id [Integer]
  # @param actor_id   [Integer] User id for audit context
  def perform(invoice_id, actor_id: nil)
    invoice = SalesInvoice.includes(:organization, :branch, :customer, :lines)
                          .find(invoice_id)

    Current.user         = User.find_by(id: actor_id) if actor_id
    Current.organization = invoice.organization

    renderer = ApplicationController.renderer.new(
      http_host: invoice.organization.subdomain || "app.orderlane.io"
    )

    html = renderer.render(
      template: "invoices/pdf",
      layout:   "pdf",
      assigns:  { invoice: invoice }
    )

    pdf_bytes = WickedPdf.new.pdf_from_string(html)

    invoice.pdf_document.attach(
      io:           StringIO.new(pdf_bytes),
      filename:     "#{invoice.invoice_number}.pdf",
      content_type: "application/pdf"
    )

    invoice.update_columns(pdf_generated_at: Time.current)

    AuditLog.create!(
      organization: invoice.organization,
      actor:        Current.user || invoice.created_by,
      auditable:    invoice,
      action:       "invoice_pdf_generated",
      changes_data: { invoice_number: invoice.invoice_number }
    )

    Rails.logger.info("[GenerateInvoicePdfJob] PDF attached to Invoice##{invoice_id}")
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    Rails.logger.error("[GenerateInvoicePdfJob] Failed for Invoice##{invoice_id}: #{e.message}")
    raise
  end
end
