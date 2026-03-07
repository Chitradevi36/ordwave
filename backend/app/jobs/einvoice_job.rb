# Enqueues an asynchronous IRP (Invoice Registration Portal) e-invoice
# generation request for a given SalesInvoice.
#
# Usage (fire-and-forget):
#   EinvoiceJob.perform_later(invoice.id)
#
# The job is idempotent: it skips silently if the invoice already has an IRN
# or is no longer in 'issued' status.
class EinvoiceJob < ApplicationJob
  queue_as :default

  # Retry on transient network / IRP errors with exponential back-off.
  # After 3 attempts the job moves to the dead-job queue and the invoice
  # retains einvoice_status: "failed" with the last error message.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(invoice_id)
    invoice = SalesInvoice.find_by(id: invoice_id)

    unless invoice
      Rails.logger.warn("[EinvoiceJob] Invoice##{invoice_id} not found — skipping")
      return
    end

    if invoice.irn.present?
      Rails.logger.info("[EinvoiceJob] Invoice##{invoice_id} already has IRN #{invoice.irn} — skipping")
      return
    end

    unless invoice.issued?
      Rails.logger.warn("[EinvoiceJob] Invoice##{invoice_id} is not issued (status=#{invoice.status}) — skipping")
      return
    end

    result = Gst::EinvoiceService.call(invoice: invoice)

    if result.success?
      Rails.logger.info("[EinvoiceJob] IRN generated for Invoice##{invoice_id}: #{result.irn}")
    else
      Rails.logger.error("[EinvoiceJob] IRN generation failed for Invoice##{invoice_id}: #{result.errors.join(', ')}")
      raise result.errors.first  # triggers retry_on
    end
  end
end
