module Inventory
  # Reserves stock for all lines on an approved SalesOrder.
  # Creates one InventoryReservation per line + one StockMovement(sale_reserved) per line.
  # Returns a Result that summarises any lines that could not be fully reserved.
  #
  class ReserveForOrder
    LineResult = Struct.new(:line, :success?, :message)
    Result     = Struct.new(:success?, :line_results, :errors)

    def self.call(**args)
      new(**args).call
    end

    def initialize(sales_order:, actor:)
      @order = sales_order
      @actor = actor
    end

    def call
      unless %w[approved].include?(@order.status)
        return Result.new(false, [], ['Order must be in approved status to reserve stock'])
      end

      line_results = []
      overall_errors = []

      ActiveRecord::Base.transaction do
        @order.lines.includes(:product).each do |line|
          result = reserve_line(line)
          line_results << result
          unless result.success?
            overall_errors << "Line #{line.id} (#{line.product.name}): #{result.message}"
          end
        end

        # Rollback the whole transaction if any line fails
        if overall_errors.any?
          raise ActiveRecord::Rollback
        end
      end

      if overall_errors.empty?
        Result.new(true, line_results, [])
      else
        Result.new(false, line_results, overall_errors)
      end
    end

    private

    def reserve_line(line)
      # Idempotency: skip if already reserved for this line
      existing = InventoryReservation.active.find_by(
        sales_order_id:      @order.id,
        sales_order_line_id: line.id
      )
      return LineResult.new(line, true, 'Already reserved') if existing

      mv_result = Inventory::PostMovement.call(
        org:               @order.organization,
        branch:            @order.branch,
        product:           line.product,
        movement_type:     'sale_reserved',
        quantity:          line.qty,
        reference:         @order,
        reference_line_id: line.id,
        actor:             @actor,
        metadata:          { order_number: @order.order_number }
      )

      unless mv_result.success?
        return LineResult.new(line, false, mv_result.errors.join(', '))
      end

      InventoryReservation.create!(
        organization:        @order.organization,
        branch:              @order.branch,
        product:             line.product,
        sales_order:         @order,
        sales_order_line_id: line.id,
        qty_reserved:        line.qty,
        status:              'active'
      )

      LineResult.new(line, true, nil)
    end
  end
end
