module Transfers
  # Receives (GRN) a dispatched / partially-received transfer.
  # Posts transfer_in movements at destination for qty_received.
  # Damaged qty is recorded but NOT posted to on_hand.
  #
  # Idempotency: guarded by (reference_type, reference_id, reference_line_id, movement_type)
  # uniqueness on stock_movements.
  #
  class ReceiveTransfer
    Result = Struct.new(:success?, :transfer, :errors)

    # received_lines: [{line_id:, qty_received:, qty_damaged:, reason_code:}, ...]
    def initialize(transfer:, actor:, received_lines:)
      @transfer       = transfer
      @actor          = actor
      @received_lines = received_lines.map { |l|
        l.is_a?(ActionController::Parameters) ? l.to_h.deep_symbolize_keys : l
      }
    end

    def call
      unless @transfer.receivable?
        return Result.new(false, @transfer,
          ["Transfer cannot be received from '#{@transfer.status}' status"])
      end

      if @received_lines.blank?
        return Result.new(false, @transfer, ['At least one line is required'])
      end

      errors = []

      ActiveRecord::Base.transaction do
        @received_lines.each do |rl|
          line = @transfer.lines.find { |l| l.id == rl[:line_id].to_i }
          unless line
            errors << "Line #{rl[:line_id]} not found on this transfer"
            next
          end

          qty_received = rl[:qty_received].to_d
          qty_damaged  = rl[:qty_damaged].to_d

          remaining = line.qty_dispatched - line.qty_received - line.qty_damaged
          if (qty_received + qty_damaged) > remaining + 0.0001
            errors << "#{line.product&.sku}: qty_received + qty_damaged (#{qty_received + qty_damaged}) exceeds remaining in-transit (#{remaining})"
            next
          end

          # Idempotency guard
          if already_received?(line)
            errors << "#{line.product&.sku}: already received in this batch"
            next
          end

          # Post transfer_in movement for qty_received at destination
          if qty_received > 0
            result = Inventory::PostMovement.call(
              org:               @transfer.organization,
              branch:            @transfer.destination_branch,
              product:           line.product,
              movement_type:     'transfer_in',
              quantity:          qty_received,
              reference:         @transfer,
              reference_line_id: line.id,
              actor:             @actor,
              metadata: {
                source_branch_id: @transfer.source_branch_id,
                transfer_number:  @transfer.transfer_number,
                qty_damaged:      qty_damaged
              }
            )

            unless result.success?
              errors.concat(result.errors)
              next
            end
          end

          line.update!(
            qty_received:  line.qty_received  + qty_received,
            qty_damaged:   line.qty_damaged   + qty_damaged,
            reason_code:   rl[:reason_code] || line.reason_code
          )
        end

        unless errors.empty?
          raise ActiveRecord::Rollback
        end

        new_status = compute_status
        @transfer.update!(
          status:      new_status,
          received_by: @actor,
          received_at: Time.current
        )

        audit_action = new_status == 'received' ? 'transfer_received' : 'transfer_partially_received'
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @transfer.organization,
          auditable:    @transfer,
          action:       audit_action,
          changes: {
            transfer_number: @transfer.transfer_number,
            received_at:     @transfer.received_at,
            new_status:      new_status
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

    def already_received?(line)
      StockMovement.exists?(
        reference_type:    'StockTransfer',
        reference_id:      @transfer.id,
        reference_line_id: line.id,
        movement_type:     'transfer_in'
      )
    end

    def compute_status
      # Reload lines to get freshest qty values
      lines = @transfer.lines.reload
      all_accounted = lines.all?(&:fully_accounted?)
      all_accounted ? 'received' : 'partially_received'
    end
  end
end
