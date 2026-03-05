module Inventory
  # Called when a SalesOrder is dispatched or delivered.
  # Converts reserved stock into actual on-hand deductions:
  #   - Posts StockMovement(sale_dispatched | sale_delivered) which debits BOTH on_hand AND reserved
  #   - Marks InventoryReservations as consumed
  #
  class ReleaseReservation
    Result = Struct.new(:success?, :errors)

    DISPATCH_EVENT_TO_TYPE = {
      dispatched: 'sale_dispatched',
      delivered:  'sale_delivered'
    }.freeze

    def self.call(**args)
      new(**args).call
    end

    def initialize(sales_order:, actor:, event:)
      # event: :dispatched | :delivered
      @order = sales_order
      @actor = actor
      @event = event
    end

    def call
      movement_type = DISPATCH_EVENT_TO_TYPE[@event&.to_sym]
      unless movement_type
        return Result.new(false, ["Unknown dispatch event: #{@event}"])
      end

      reservations = InventoryReservation.active.where(sales_order: @order).includes(:product)
      return Result.new(true, []) if reservations.empty?

      errors = []

      ActiveRecord::Base.transaction do
        reservations.each do |reservation|
          mv_result = Inventory::PostMovement.call(
            org:               @order.organization,
            branch:            @order.branch,
            product:           reservation.product,
            movement_type:     movement_type,
            quantity:          reservation.qty_reserved,
            reference:         @order,
            reference_line_id: reservation.sales_order_line_id,
            actor:             @actor,
            metadata:          { order_number: @order.order_number }
          )

          unless mv_result.success?
            errors.concat(mv_result.errors)
            raise ActiveRecord::Rollback
          end

          reservation.consume!
        end
      end

      errors.empty? ? Result.new(true, []) : Result.new(false, errors)
    end
  end
end
