module PurchaseInvoices
  # Transitions a draft PurchaseInvoice to 'posted'.
  # Side effects:
  #   1. Creates one StockMovement (purchase_posted / in) per line via Inventory::ApplyPurchaseInvoicePosting.
  #   2. Increases InventoryLevel qty_on_hand for each line's product on the invoice's branch.
  #   3. Writes a purchase_invoice_posted audit log entry.
  #
  class PostService
    Result = Struct.new(:success?, :invoice, :errors)

    def initialize(invoice:, actor:)
      @invoice = invoice
      @actor   = actor
    end

    def call
      unless @invoice.draft?
        return Result.new(false, @invoice,
                          ["Invoice is already #{@invoice.status} — cannot post"])
      end

      if @invoice.lines.empty?
        return Result.new(false, @invoice, ['Cannot post an invoice with no lines'])
      end

      inv_errors = []

      ActiveRecord::Base.transaction do
        # 1. Apply stock movements via inventory ledger service
        inv_result = Inventory::ApplyPurchaseInvoicePosting.call(
          invoice: @invoice,
          actor:   @actor,
          action:  :post
        )

        unless inv_result.success?
          inv_errors = inv_result.errors
          raise ActiveRecord::Rollback
        end

        # 2. Transition invoice status
        @invoice.update!(status: 'posted', posted_at: Time.current)

        # 3. Audit log
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @invoice.organization,
          auditable:    @invoice.supplier,
          action:       'purchase_invoice_posted',
          changes:      {
            invoice_number: @invoice.invoice_number,
            grand_total:    @invoice.grand_total,
            lines_count:    @invoice.lines.size
          }
        )
      end

      return Result.new(false, @invoice, inv_errors) if inv_errors.any?

      Result.new(true, @invoice, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @invoice, [e.message])
    end
  end
end
