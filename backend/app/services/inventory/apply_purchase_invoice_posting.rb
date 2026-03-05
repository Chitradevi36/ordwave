module Inventory
  # Applies stock movements when a PurchaseInvoice is posted or cancelled.
  # Idempotent: checks for existing movements for the invoice before creating new ones
  # so it is safe to call twice without double-counting.
  #
  class ApplyPurchaseInvoicePosting
    Result = Struct.new(:success?, :errors)

    def self.call(**args)
      new(**args).call
    end

    def initialize(invoice:, actor:, action:)
      # action: :post | :cancel
      @invoice = invoice
      @actor   = actor
      @action  = action
    end

    def call
      case @action
      when :post
        apply_posting
      when :cancel
        apply_cancellation
      else
        Result.new(false, ["Unknown action: #{@action}"])
      end
    end

    private

    def apply_posting
      return Result.new(false, ['Invoice is not in draft status']) unless @invoice.draft?
      return Result.new(false, ['Invoice has no lines']) if @invoice.lines.empty?

      # Idempotency check: skip if already posted movements exist
      if already_moved?('purchase_posted')
        return Result.new(true, [])
      end

      errors = []
      ActiveRecord::Base.transaction do
        @invoice.lines.each do |line|
          result = Inventory::PostMovement.call(
            org:           @invoice.organization,
            branch:        @invoice.branch,
            product:       line.product,
            movement_type: 'purchase_posted',
            quantity:      line.qty,
            unit_cost:     line.unit_price,
            reference:     @invoice,
            reference_line_id: line.id,
            actor:         @actor,
            metadata:      { invoice_number: @invoice.invoice_number }
          )
          unless result.success?
            errors.concat(result.errors)
            raise ActiveRecord::Rollback
          end
        end
      end

      errors.empty? ? Result.new(true, []) : Result.new(false, errors)
    end

    def apply_cancellation
      was_posted = @invoice.posted?

      errors = []
      ActiveRecord::Base.transaction do
        if was_posted && !already_moved?('purchase_cancelled')
          @invoice.lines.each do |line|
            result = Inventory::PostMovement.call(
              org:           @invoice.organization,
              branch:        @invoice.branch,
              product:       line.product,
              movement_type: 'purchase_cancelled',
              quantity:      line.qty,
              unit_cost:     line.unit_price,
              reference:     @invoice,
              reference_line_id: line.id,
              actor:         @actor,
              metadata:      {
                invoice_number: @invoice.invoice_number,
                reason:         'Invoice cancelled'
              }
            )
            unless result.success?
              errors.concat(result.errors)
              raise ActiveRecord::Rollback
            end
          end
        end
      end

      errors.empty? ? Result.new(true, []) : Result.new(false, errors)
    end

    def already_moved?(movement_type)
      StockMovement.where(
        reference_type: 'PurchaseInvoice',
        reference_id:   @invoice.id,
        movement_type:  movement_type
      ).exists?
    end
  end
end
