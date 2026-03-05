module Api
  module V1
    class SuppliersController < BaseController
      before_action :require_organization!
      before_action :set_supplier, only: %i[show update destroy blacklist activate]

      def index
        scope     = policy_scope(Supplier)
        scope     = scope.by_status(params[:status]) if params[:status].present?
        scope     = scope.search_query(params[:q])   if params[:q].present?
        suppliers = paginate(scope.includes(:supplier_products).order(name: :asc))

        render_success(
          suppliers.map { |s| serialize_supplier(s) },
          meta: pagination_meta(suppliers)
        )
      end

      def show
        authorize @supplier
        render_success(serialize_supplier(@supplier, detailed: true))
      end

      def create
        authorize Supplier.new(organization: current_organization)

        result = Suppliers::CreateSupplierService.new(
          params:       supplier_params,
          organization: current_organization,
          actor:        current_user
        ).call

        if result.success?
          render_created(serialize_supplier(result.supplier, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      def update
        authorize @supplier

        result = Suppliers::UpdateSupplierService.new(
          supplier: @supplier,
          params:   supplier_params,
          actor:    current_user
        ).call

        if result.success?
          render_success(serialize_supplier(result.supplier, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      def destroy
        authorize @supplier

        result = Suppliers::SoftDeleteSupplierService.new(
          supplier: @supplier,
          actor:    current_user,
          reason:   params[:reason]
        ).call

        if result.success?
          render_success({ message: 'Supplier deleted' })
        else
          render_errors(result.errors)
        end
      end

      def blacklist
        authorize @supplier, :update?
        @supplier.blacklist!
        render_success(serialize_supplier(@supplier))
      end

      def activate
        authorize @supplier, :update?
        @supplier.activate!
        render_success(serialize_supplier(@supplier))
      end

      private

      def set_supplier
        @supplier = Supplier.not_deleted
                            .where(organization: current_organization)
                            .includes(supplier_products: :product)
                            .find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(
          :name, :code, :status, :phone, :email, :contact_person,
          :gstin, :pan, :address, :city, :state, :pincode,
          :bank_name, :bank_account, :bank_ifsc,
          :payment_terms_days, :credit_limit, :notes
        )
      end

      def serialize_supplier(supplier, detailed: false)
        data = {
          id:                  supplier.id,
          name:                supplier.name,
          code:                supplier.code,
          status:              supplier.status,
          phone:               supplier.phone,
          email:               supplier.email,
          contact_person:      supplier.contact_person,
          gstin:               supplier.gstin,
          pan:                 supplier.pan,
          address:             supplier.address,
          city:                supplier.city,
          state:               supplier.state,
          pincode:             supplier.pincode,
          payment_terms_days:  supplier.payment_terms_days,
          credit_limit:        supplier.credit_limit,
          notes:               supplier.notes,
          created_at:          supplier.created_at,
          updated_at:          supplier.updated_at
        }

        if detailed
          data[:bank_name]     = supplier.bank_name
          data[:bank_account]  = supplier.bank_account
          data[:bank_ifsc]     = supplier.bank_ifsc
          data[:supplier_products] = (supplier.supplier_products || []).map do |sp|
            serialize_supplier_product(sp)
          end
        else
          data[:supplier_products_count] = supplier.supplier_products.size
        end

        data
      end

      def serialize_supplier_product(sp)
        {
          id:             sp.id,
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
