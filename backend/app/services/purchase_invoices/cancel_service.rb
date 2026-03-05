module PurchaseInvoices
  # Cancels a PurchaseInvoice (draft or posted).
  # When cancelling a POSTED invoice:
  #   1. Creates reversal StockMovements (purchase_cancelled / out) per line via
  #      Inventory::ApplyPurchaseInvoicePosting.
  #   2. Decreases InventoryLevel qty_on_hand back.
  # Always:
  #   3. Writes a purchase_invoice_cancelled audit log entry.
  #
  class CancelService
    Result = Struct.new(:success?, :invoice, :errors)

    def initialize(invoice:, actor:, reason: nil)
      @invoice = invoice
      @actor   = actor
      @reason  = reason
    end

    def call
      if @invoice.cancelled?
        return Result.new(false, @invoice, ['Invoice is already cancelled'])
      end

      was_posted = @invoice.posted?
      inv_errors = []

      ActiveRecord::Base.transaction do
        # 1. If posted, reverse stock movements via inventory ledger service
        if was_posted
          inv_result = Inventory::ApplyPurchaseInvoicePosting.call(
            invoice: @invoice,
            actor:   @actor,
            action:  :cancel
          )

          unless inv_result.success?
            inv_errors = inv_result.errors
            raise ActiveRecord::Rollback
          end
        end

        # 2. Transition invoice status
        @invoice.update!(
          status:              'cancelled',
          cancelled_at:        Time.current,
          cancellation_reason: @reason
        )

        # 3. Audit log
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @invoice.organization,
          auditable:    @invoice.supplier,
          action:       'purchase_invoice_cancelled',
          changes:      {
            invoice_number:  @invoice.invoice_number,
            reason:          @reason,
            stock_reversed:  was_posted
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
