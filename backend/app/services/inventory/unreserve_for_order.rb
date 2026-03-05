module Inventory
  # Releases all active reservations for a SalesOrder (e.g. when the order is cancelled).
  # Creates StockMovement(sale_unreserved) per line and marks reservations as released.
  #
  class UnreserveForOrder
    Result = Struct.new(:success?, :errors)

    def self.call(**args)
      new(**args).call
    end

    def initialize(sales_order:, actor:, reason: nil)
      @order  = sales_order
      @actor  = actor
      @reason = reason
    end

    def call
      reservations = InventoryReservation.active.where(sales_order: @order).includes(:product)
      return Result.new(true, []) if reservations.empty?

      errors = []

      ActiveRecord::Base.transaction do
        reservations.each do |reservation|
          mv_result = Inventory::PostMovement.call(
            org:               @order.organization,
            branch:            @order.branch,
            product:           reservation.product,
            movement_type:     'sale_unreserved',
            quantity:          reservation.qty_reserved,
            reference:         @order,
            reference_line_id: reservation.sales_order_line_id,
            actor:             @actor,
            metadata:          {
              order_number: @order.order_number,
              reason:       @reason
            }.compact
          )

          unless mv_result.success?
            errors.concat(mv_result.errors)
            raise ActiveRecord::Rollback
          end

          reservation.release!
        end
      end

      errors.empty? ? Result.new(true, []) : Result.new(false, errors)
    end
  end
end
