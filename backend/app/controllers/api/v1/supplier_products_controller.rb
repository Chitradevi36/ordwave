module Api
  module V1
    class SupplierProductsController < BaseController
      before_action :require_organization!
      before_action :set_supplier
      before_action :set_supplier_product, only: %i[update destroy]

      def index
        authorize SupplierProduct.new(supplier: @supplier), :index?
        products = @supplier.supplier_products.includes(:product).order(:id)
        render_success(products.map { |sp| serialize_supplier_product(sp) })
      end

      def create
        authorize SupplierProduct.new(supplier: @supplier), :create?

        result = Suppliers::UpsertSupplierProductService.new(
          supplier: @supplier,
          actor:    current_user,
          action:   'add',
          params:   supplier_product_params
        ).call

        if result.success?
          render_created(serialize_supplier_product(result.supplier_product))
        else
          render_errors(result.errors)
        end
      end

      def update
        authorize @supplier_product

        result = Suppliers::UpsertSupplierProductService.new(
          supplier:          @supplier,
          actor:             current_user,
          action:            'update',
          params:            supplier_product_params,
          supplier_product:  @supplier_product
        ).call

        if result.success?
          render_success(serialize_supplier_product(result.supplier_product))
        else
          render_errors(result.errors)
        end
      end

      def destroy
        authorize @supplier_product

        result = Suppliers::UpsertSupplierProductService.new(
          supplier:          @supplier,
          actor:             current_user,
          action:            'remove',
          supplier_product:  @supplier_product
        ).call

        if result.success?
          render_success({ message: 'Product removed from supplier' })
        else
          render_errors(result.errors)
        end
      end

      private

      def set_supplier
        @supplier = Supplier.not_deleted
                            .where(organization: current_organization)
                            .find(params[:supplier_id])
      end

      def set_supplier_product
        @supplier_product = @supplier.supplier_products.find(params[:id])
      end

      def supplier_product_params
        params.require(:supplier_product).permit(
          :product_id, :purchase_price, :supplier_sku, :lead_time_days
        )
      end

      def serialize_supplier_product(sp)
        sp.product.reload if sp.product.nil? && sp.product_id
        {
          id:             sp.id,
          supplier_id:    sp.supplier_id,
          product_id:     sp.product_id,
          product_name:   sp.product&.name,
          product_sku:    sp.product&.sku,
          purchase_price: sp.purchase_price,
          supplier_sku:   sp.supplier_sku,
          lead_time_days: sp.lead_time_days,
          created_at:     sp.created_at,
          updated_at:     sp.updated_at
        }
      end
    end
  end
end
