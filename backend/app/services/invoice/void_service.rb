module Invoice
  # Voids an issued SalesInvoice.
  #
  # Rules:
  #   - Only issued invoices can be voided.
  #   - Void reason is mandatory.
  #   - Lines are preserved; invoice is soft-marked void (no hard delete).
  #   - `sales_order_lines.invoiced_qty` is decremented so the qty can be re-invoiced.
  #   - Writes an audit trail entry.
  #
  # Credit note / payment reversal logic is intentionally out of scope (v2).
  #
  class VoidService
    Result = Struct.new(:success?, :invoice, :errors, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, invoice:, reason:)
      @actor   = actor
      @invoice = invoice
      @reason  = reason
    end

    def call
      errors = validate
      return Result.new(success?: false, invoice: @invoice, errors: errors) if errors.any?

      ActiveRecord::Base.transaction do
        @invoice.update!(
          status:      'void',
          voided_at:   Time.current,
          void_reason: @reason
        )

        # Decrement invoiced_qty so the qty can be re-invoiced against another invoice
        reverse_invoiced_qtys!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @invoice.organization,
          auditable:    @invoice,
          action:       'invoice_voided',
          changes: {
            invoice_number: @invoice.invoice_number,
            void_reason:    @reason,
            voided_at:      @invoice.voided_at
          },
          reason: @reason
        )

        Result.new(success?: true, invoice: @invoice.reload, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, invoice: @invoice, errors: [e.message])
    end

    private

    def validate
      errs = []

      unless @invoice.issued?
        errs << "Only issued invoices can be voided (current status: #{@invoice.status})"
      end

      errs << 'Void reason is required' if @reason.blank?

      errs
    end

    def reverse_invoiced_qtys!
      @invoice.lines.each do |inv_line|
        next unless inv_line.source_sales_order_line_id.present?

        sol = SalesOrderLine.find_by(id: inv_line.source_sales_order_line_id)
        next unless sol

        new_qty = [sol.invoiced_qty.to_d - inv_line.qty.to_d, BigDecimal('0')].max
        sol.update_column(:invoiced_qty, new_qty)
      end
    end
  end
end
