module Transfers
  # Dispatches a draft transfer: validates source stock, posts transfer_out
  # movements, marks status = dispatched.
  #
  # Idempotency: each line is guarded by a unique index on
  #   (reference_type, reference_id, reference_line_id, movement_type)
  # so calling dispatch twice for the same line raises RecordInvalid.
  #
  class DispatchTransfer
    Result = Struct.new(:success?, :transfer, :errors)

    # dispatched_lines: [{line_id:, qty_dispatched:}, ...]
    def initialize(transfer:, actor:, dispatched_lines:)
      @transfer         = transfer
      @actor            = actor
      @dispatched_lines = dispatched_lines.map { |l|
        l.is_a?(ActionController::Parameters) ? l.to_h.deep_symbolize_keys : l
      }
    end

    def call
      unless @transfer.dispatchable?
        return Result.new(false, @transfer, ["Transfer cannot be dispatched from '#{@transfer.status}' status"])
      end

      if @dispatched_lines.blank?
        return Result.new(false, @transfer, ['At least one line with qty_dispatched is required'])
      end

      errors = []

      ActiveRecord::Base.transaction do
        @dispatched_lines.each do |dl|
          line = @transfer.lines.find { |l| l.id == dl[:line_id].to_i }
          unless line
            errors << "Line #{dl[:line_id]} not found on this transfer"
            next
          end

          qty = dl[:qty_dispatched].to_d
          if qty <= 0
            errors << "#{line.product&.sku}: qty_dispatched must be positive"
            next
          end

          # Idempotency guard: skip if already posted for this line
          if already_dispatched?(line)
            errors << "#{line.product&.sku}: already dispatched"
            next
          end

          # Post transfer_out movement — PostMovement validates sufficient stock
          result = Inventory::PostMovement.call(
            org:               @transfer.organization,
            branch:            @transfer.source_branch,
            product:           line.product,
            movement_type:     'transfer_out',
            quantity:          qty,
            reference:         @transfer,
            reference_line_id: line.id,
            actor:             @actor,
            metadata: {
              destination_branch_id: @transfer.destination_branch_id,
              transfer_number:       @transfer.transfer_number
            }
          )

          unless result.success?
            errors.concat(result.errors)
            next
          end

          line.update!(qty_dispatched: qty)
        end

        unless errors.empty?
          raise ActiveRecord::Rollback
        end

        @transfer.update!(
          status:         'dispatched',
          dispatched_by:  @actor,
          dispatched_at:  Time.current
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @transfer.organization,
          auditable:    @transfer,
          action:       'transfer_dispatched',
          changes: {
            transfer_number: @transfer.transfer_number,
            dispatched_at:   @transfer.dispatched_at
          }
        )
      end

      if errors.any?
        Result.new(false, @transfer, errors)
      else
        Result.new(true, @transfer.reload, [])
      end
    end

    private

    def already_dispatched?(line)
      StockMovement.exists?(
        reference_type:    'StockTransfer',
        reference_id:      @transfer.id,
        reference_line_id: line.id,
        movement_type:     'transfer_out'
      )
    end
  end
end
