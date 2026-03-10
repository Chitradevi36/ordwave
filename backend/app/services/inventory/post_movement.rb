module Inventory
  # Single entry-point for creating a ledger entry and updating the balance row.
  #
  # Usage:
  #   result = Inventory::PostMovement.call(
  #     org:,          branch:,           product:,
  #     movement_type:, quantity:,
  #     reference:     nil,
  #     reference_line_id: nil,
  #     unit_cost:     nil,
  #     actor:         nil,
  #     occurred_at:   Time.current,
  #     metadata:      {}
  #   )
  #   result.success?  # => true/false
  #   result.movement  # => StockMovement
  #   result.errors    # => []
  #
  class PostMovement
    Result = Struct.new(:success?, :movement, :errors)

    MOVEMENT_TYPE_TO_DIRECTION = {
      'purchase_posted'   => 'in',
      'purchase_cancelled'=> 'out',
      'sale_reserved'     => 'in',   # reserved up
      'sale_unreserved'   => 'out',
      'sale_dispatched'   => 'out',
      'sale_delivered'    => 'out',
      'sale_cancelled'    => 'out',
      'return_received'            => 'in',
      'return_received_discounted' => 'in',
      'transfer_in'                => 'in',
      'transfer_out'      => 'out',
      'adjustment_in'     => 'in',
      'adjustment_out'    => 'out',
      # Legacy
      'purchase'          => 'in',
      'sale'              => 'out',
      'adjustment'        => 'in',
      'return'            => 'in',
      'reversal'          => 'out',
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
      @actor             = actor
      @occurred_at       = occurred_at || Time.current
      @metadata          = metadata || {}
    end

    def call
      validate_inputs!

      ActiveRecord::Base.transaction do
        check_negative_stock!

        movement = StockMovement.create!(
          organization:      @org,
          branch:            @branch,
          product:           @product,
          movement_type:     @movement_type,
          direction:         MOVEMENT_TYPE_TO_DIRECTION.fetch(@movement_type),
          qty:               @quantity,
          unit_cost:         @unit_cost,
          reference:         @reference,
          reference_line_id: @reference_line_id,
          created_by:        @actor,
          occurred_at:       @occurred_at,
          metadata:          @metadata
        )

        InventoryLevel.apply_movement_delta(
          organization:   @org,
          branch:         @branch,
          product:        @product,
          on_hand_delta:  movement.on_hand_delta,
          reserved_delta: movement.reserved_delta
        )

        Result.new(true, movement, [])
      end
    rescue ActiveRecord::ReadOnlyRecord, ArgumentError => e
      Result.new(false, nil, [e.message])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, [e.message])
    end

    private

    def validate_inputs!
      raise ArgumentError, "movement_type '#{@movement_type}' is not valid" unless
        StockMovement::MOVEMENT_TYPES.include?(@movement_type)
      raise ArgumentError, 'quantity must be positive' unless @quantity > 0
    end

    # Prevent on_hand from going negative for sale-type dispatches.
    # Adjustments are allowed if policy permits (caller must gate).
    def check_negative_stock!
      out_types = %w[sale_dispatched sale_delivered purchase_cancelled transfer_out]
      return unless out_types.include?(@movement_type)

      level = InventoryLevel.find_by(
        organization: @org,
        branch:       @branch,
        product:      @product
      )
      available = level&.qty_available.to_d
      if available < @quantity
        raise ArgumentError,
              "Insufficient available stock for #{@product.sku} at #{@branch.name}: " \
              "requested #{@quantity}, available #{available}"
      end
    end
  end
end
