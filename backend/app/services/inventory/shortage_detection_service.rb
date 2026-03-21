module Inventory
  # Feature 12: Detects inventory shortages during order approval/creation
  #
  # When an order is about to be approved or created for delivery,
  # this service checks if sufficient inventory exists in the branch.
  #
  # Returns shortage details with customer resolution options:
  #   - Refund: Cancel order and refund customer
  #   - Partial: Deliver available quantity only
  #   - Reschedule: Reschedule for future delivery when stock arrives
  #   - Override: Manager approval to proceed despite shortage
  #
  # Usage:
  #   result = Inventory::ShortageDetectionService.call(
  #     order:     sales_order,
  #     branch:    branch,
  #     actor:     current_user
  #   )
  #
  #   result.has_shortage?          # => true/false
  #   result.shortage_items         # => [{ product_id, available, requested, ... }]
  #   result.total_shortage_value   # => ₹5,000 (value of shortage)
  #   result.resolution_options     # => [:refund, :partial, :reschedule]
  #
  class ShortageDetectionService
    Result = Struct.new(:has_shortage?, :shortage_items, :total_shortage_value,
                        :resolution_options, :errors, keyword_init: true)

    ShortageItem = Struct.new(:product_id, :product_name, :product_sku,
                             :requested_qty, :available_qty, :shortage_qty,
                             :unit_price, :shortage_value, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    # @param order       [SalesOrder] the order to check for shortages
    # @param branch      [Branch] warehouse branch (defaults to order.branch)
    # @param actor       [User] for audit logging
    def initialize(order:, branch: nil, actor: nil)
      @order    = order
      @branch   = branch || order.branch
      @actor    = actor
      @errors   = []
    end

    def call
      shortages = detect_shortages
      
      if shortages.empty?
        return Result.new(
          has_shortage?: false,
          shortage_items: [],
          total_shortage_value: 0,
          resolution_options: [],
          errors: []
        )
      end

      total_value = shortages.sum { |s| s.shortage_value }
      resolution_opts = determine_resolution_options(shortages)

      Result.new(
        has_shortage?: true,
        shortage_items: shortages,
        total_shortage_value: total_value,
        resolution_options: resolution_opts,
        errors: []
      )
    end

    private

    def detect_shortages
      shortages = []

      @order.lines.each do |line|
        inventory_level = InventoryLevel.find_or_create_by(
          organization: @order.organization,
          branch: @branch,
          product: line.product
        )

        available = inventory_level.qty_available.to_d
        requested = line.qty.to_d

        if available < requested
          shortage_qty = requested - available
          shortage_value = (shortage_qty * line.unit_price).round(2)

          shortages << ShortageItem.new(
            product_id: line.product_id,
            product_name: line.product.name,
            product_sku: line.product.sku,
            requested_qty: requested,
            available_qty: available,
            shortage_qty: shortage_qty,
            unit_price: line.unit_price,
            shortage_value: shortage_value
          )
        end
      end

      shortages
    end

    def determine_resolution_options(shortages)
      options = []

      # All shortages can be offered refund
      options << :refund

      # Partial is possible if at least some items are available
      options << :partial if shortages.any? { |s| s.available_qty > 0 }

      # Reschedule is always available
      options << :reschedule

      options
    end
  end
end
