module Inventory
  # Concurrency-safe stock update using PostgreSQL row-level locking (FOR UPDATE).
  #
  # Use this service for any write that modifies qty_on_hand / qty_reserved to
  # guarantee correctness under concurrent Sidekiq workers.
  #
  # Usage:
  #   result = Inventory::UpdateStockService.call(
  #     org:            organization,
  #     branch:         branch,
  #     product:        product,
  #     movement_type:  "sale_dispatched",   # must be a valid StockMovement type
  #     quantity:       10,
  #     reference:      sales_order,         # optional polymorphic reference
  #     unit_cost:      nil,                 # optional
  #     actor:          current_user,        # optional – for AuditLog / ledger
  #     metadata:       {}                   # optional
  #   )
  #
  #   result.success?   # => true / false
  #   result.level      # => InventoryLevel record (updated)
  #   result.movement   # => StockMovement record
  #   result.errors     # => Array<String>
  #
  class UpdateStockService
    Result = Struct.new(:success?, :level, :movement, :errors)

    DIRECTION = {
      'purchase_posted'    => { on_hand: +1, reserved:  0 },
      'purchase_cancelled' => { on_hand: -1, reserved:  0 },
      'sale_reserved'      => { on_hand:  0, reserved: +1 },
      'sale_unreserved'    => { on_hand:  0, reserved: -1 },
      'sale_dispatched'    => { on_hand: -1, reserved: -1 },
      'sale_delivered'     => { on_hand:  0, reserved:  0 }, # no-op balance; movement for ledger only
      'sale_cancelled'     => { on_hand:  0, reserved: -1 },
      'return_received'    => { on_hand: +1, reserved:  0 },
      'transfer_in'        => { on_hand: +1, reserved:  0 },
      'transfer_out'       => { on_hand: -1, reserved:  0 },
      'adjustment_in'      => { on_hand: +1, reserved:  0 },
      'adjustment_out'     => { on_hand: -1, reserved:  0 },
    }.freeze

    def self.call(**args)
      new(**args).call
    end

    def initialize(org:, branch:, product:, movement_type:, quantity:,
                   reference: nil, reference_line_id: nil, unit_cost: nil,
                   actor: nil, occurred_at: nil, metadata: {})
      @org               = org
      @branch            = branch
      @product           = product
      @movement_type     = movement_type
      @quantity          = quantity.to_d
      @reference         = reference
      @reference_line_id = reference_line_id
      @unit_cost         = unit_cost
      @actor             = actor || Current.user
      @occurred_at       = occurred_at || Time.current
      @metadata          = metadata || {}
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        # Pessimistic lock — only one worker can update this row at a time.
        level = InventoryLevel
                  .lock("FOR UPDATE")
                  .find_or_initialize_by(
                    organization: @org,
                    branch:       @branch,
                    product:      @product
                  )
        level.qty_on_hand  ||= 0
        level.qty_reserved ||= 0

        deltas = DIRECTION.fetch(@movement_type)
        on_hand_delta  = deltas[:on_hand]  * @quantity
        reserved_delta = deltas[:reserved] * @quantity

        # Guard: available stock check before consuming
        if on_hand_delta < 0
          available = level.qty_on_hand - level.qty_reserved
          available = [available, 0].max
          if available < @quantity && !adjustment?
            raise StockInsufficientError,
                  "Insufficient stock for #{@product.sku} at #{@branch.name}: " \
                  "requested #{@quantity}, available #{available}"
          end
        end

        level.qty_on_hand  = [level.qty_on_hand  + on_hand_delta,  0].max
        level.qty_reserved = [level.qty_reserved + reserved_delta, 0].max
        level.save!

        # Write ledger entry for traceability
        movement = StockMovement.create!(
          organization:      @org,
          branch:            @branch,
          product:           @product,
          movement_type:     @movement_type,
          direction:         on_hand_delta >= 0 ? "in" : "out",
          qty:               @quantity,
          unit_cost:         @unit_cost,
          reference:         @reference,
          reference_line_id: @reference_line_id,
          created_by:        @actor,
          occurred_at:       @occurred_at,
          metadata:          @metadata
        )

        # Emit low-stock notification if threshold crossed
        notify_low_stock!(level) if level.low_stock?

        Result.new(true, level, movement, [])
      end
    rescue StockInsufficientError => e
      Result.new(false, nil, nil, [e.message])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, nil, e.record.errors.full_messages)
    rescue ArgumentError => e
      Result.new(false, nil, nil, [e.message])
    end

    # ── Custom error class ───────────────────────────────────────────────────
    class StockInsufficientError < StandardError; end

    private

    def validate!
      raise ArgumentError, "movement_type '#{@movement_type}' is unknown" \
        unless DIRECTION.key?(@movement_type)
      raise ArgumentError, "quantity must be positive" unless @quantity > 0
      raise ArgumentError, "org is required"     unless @org
      raise ArgumentError, "branch is required"  unless @branch
      raise ArgumentError, "product is required" unless @product
    end

    def adjustment?
      @movement_type.start_with?("adjustment")
    end

    def notify_low_stock!(level)
      # Fire-and-forget — background job picks this up
      LowStockNotificationJob.perform_later(
        organization_id: @org.id,
        branch_id:       @branch.id,
        product_id:      @product.id,
        qty_on_hand:     level.qty_on_hand,
        threshold:       level.min_qty_threshold
      )
    rescue NameError
      # Job class not loaded in this context — skip
      Rails.logger.warn("[UpdateStockService] LowStockNotificationJob not found, skipping")
    end
  end
end
