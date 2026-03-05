module Suppliers
  # Manages supplier_products:
  #   action: 'add'    — create a new mapping
  #   action: 'update' — update purchase_price / supplier_sku / lead_time_days
  #   action: 'remove' — hard-delete the mapping (non-financial join row)
  #
  class UpsertSupplierProductService
    Result = Struct.new(:success?, :supplier_product, :errors)

    def initialize(supplier:, actor:, action:, params: {}, supplier_product: nil)
      @supplier         = supplier
      @actor            = actor
      @action           = action.to_s
      @params           = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @supplier_product = supplier_product
    end

    def call
      case @action
      when 'add'    then add_product
      when 'update' then update_product
      when 'remove' then remove_product
      else
        Result.new(false, nil, ["Unknown action '#{@action}'"])
      end
    end

    private

    def add_product
      sp = SupplierProduct.new(
        supplier:       @supplier,
        product_id:     @params[:product_id],
        purchase_price: @params[:purchase_price],
        supplier_sku:   @params[:supplier_sku],
        lead_time_days: @params[:lead_time_days]
      )

      if sp.save
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @supplier.organization,
          auditable:    @supplier,
          action:       'supplier_product_added',
          changes:      { product_id: sp.product_id, purchase_price: sp.purchase_price }
        )
        Result.new(true, sp, [])
      else
        Result.new(false, nil, sp.errors.full_messages)
      end
    end

    def update_product
      return Result.new(false, nil, ['SupplierProduct not found']) unless @supplier_product

      permitted = @params.slice(:purchase_price, :supplier_sku, :lead_time_days)
      if @supplier_product.update(permitted)
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @supplier.organization,
          auditable:    @supplier,
          action:       'supplier_product_updated',
          changes:      @supplier_product.previous_changes.except('updated_at')
        )
        Result.new(true, @supplier_product, [])
      else
        Result.new(false, @supplier_product, @supplier_product.errors.full_messages)
      end
    end

    def remove_product
      return Result.new(false, nil, ['SupplierProduct not found']) unless @supplier_product

      product_id = @supplier_product.product_id
      @supplier_product.destroy!

      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @supplier.organization,
        auditable:    @supplier,
        action:       'supplier_product_removed',
        changes:      { product_id: product_id }
      )

      Result.new(true, nil, [])
    end
  end
end
