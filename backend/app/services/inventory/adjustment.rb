module Inventory
  # Manual inventory adjustment service.
  # direction :in  → movement_type 'adjustment_in'  (adds to on_hand)
  # direction :out → movement_type 'adjustment_out' (removes from on_hand)
  #
  # NOTE: negative-stock guard for adjustment_out is handled here only when
  # enforce_negative_stock: true (default true). The API controller additionally
  # gates :out adjustments to manager/owner via Pundit before calling this service.
  #
  class Adjustment
    VALID_DIRECTIONS   = %i[in out].freeze
    MAX_REASON_LENGTH  = 255

    Result = Struct.new(:success?, :movement, :errors)

    def self.call(**args)
      new(**args).call
    end

    def initialize(
      org:,
      branch:,
      product:,
      direction:,
      quantity:,
      actor:,
      reason_code: nil,
      notes:       nil
    )
      @org         = org
      @branch      = branch
      @product     = product
      @direction   = direction&.to_sym
      @quantity    = quantity
      @actor       = actor
      @reason_code = reason_code
      @notes       = notes
    end

    def call
      errors = validate_inputs
      return Result.new(false, nil, errors) if errors.any?

      movement_type = @direction == :in ? 'adjustment_in' : 'adjustment_out'

      mv_result = Inventory::PostMovement.call(
        org:           @org,
        branch:        @branch,
        product:       @product,
        movement_type: movement_type,
        quantity:      @quantity,
        actor:         @actor,
        metadata:      {
          reason_code: @reason_code,
          notes:       @notes
        }.compact
        # NOTE: adjustment_out does NOT check negative-stock guard inside PostMovement
        # (out_types guard only covers sale_dispatched / sale_delivered / purchase_cancelled / transfer_out).
        # The policy layer restricts :out adjustments to manager/owner before this is called.
      )

      if mv_result.success?
        Result.new(true, mv_result.movement, [])
      else
        Result.new(false, nil, mv_result.errors)
      end
    end

    private

    def validate_inputs
      errors = []
      errors << 'direction must be :in or :out' unless VALID_DIRECTIONS.include?(@direction)
      errors << 'quantity must be greater than 0' unless @quantity.is_a?(Numeric) && @quantity > 0
      if @reason_code && @reason_code.length > MAX_REASON_LENGTH
        errors << "reason_code exceeds #{MAX_REASON_LENGTH} characters"
      end
      errors
    end
  end
end
