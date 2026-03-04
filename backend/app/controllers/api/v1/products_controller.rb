require 'csv'

module Api
  module V1
    class ProductsController < BaseController
      before_action :require_organization!
      before_action :set_product, only: %i[show update destroy discontinue price]

      # GET /api/v1/products
      def index
        products = policy_scope(Product)
                     .includes(:product_category, :units_of_measure, :hsn_sac_code)
                     .order(name: :asc)
        products = products.search_sku_name(params[:q])      if params[:q].present?
        products = products.by_category(params[:category_id]) if params[:category_id].present?
        products = products.by_status(params[:status])        if params[:status].present?
        paginated = paginate(products)

        render_success(
          paginated.map { |p| serialize_product(p) },
          meta: pagination_meta(paginated)
        )
      end

      # GET /api/v1/products/:id
      def show
        authorize @product
        render_success(serialize_product(@product, detailed: true))
      end

      # POST /api/v1/products
      def create
        authorize Product.new(organization: current_organization)

        result = Products::CreateProductService.new(
          params:       product_params,
          organization: current_organization
        ).call

        if result.success?
          render_created(serialize_product(result.product, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # PATCH /api/v1/products/:id
      def update
        authorize @product

        result = Products::UpdateProductService.new(
          product: @product,
          params:  product_params
        ).call

        if result.success?
          render_success(serialize_product(result.product, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # DELETE /api/v1/products/:id
      def destroy
        authorize @product

        if @product.used_in_orders?
          render_errors(['Product is used in orders and cannot be deleted. Use Discontinue instead.'],
                        status: :unprocessable_entity)
          return
        end

        @product.soft_delete!
        render_success({ message: 'Product deleted' })
      end

      # POST /api/v1/products/bulk_import
      def bulk_import
        authorize Product.new(organization: current_organization), :bulk_import?

        unless params[:file].present?
          return render_errors(['file is required'], status: :bad_request)
        end

        result = Products::BulkImportService.new(
          file:         params[:file],
          organization: current_organization
        ).call

        render_success(
          {
            success_count: result.success_count,
            skipped_rows:  result.skipped_rows,
            failed_rows:   result.failed_rows,
            message:       "#{result.success_count} product(s) imported successfully"
          }
        )
      end

      # GET /api/v1/products/generate_sku
      def generate_sku
        authorize Product.new(organization: current_organization), :create?
        sku = Products::SkuGeneratorService.new(organization: current_organization).generate
        render_success({ sku: sku })
      end

      # GET /api/v1/products/sample_csv
      def sample_csv
        authorize Product.new(organization: current_organization), :bulk_import?

        headers_row = Products::BulkImportService::SAMPLE_HEADERS
        sample_rows = [
          [
            'PROD-001', 'Basmati Rice 5kg', 'Grains & Cereals', 'KG',
            '10061090', '10', '350.00', '8901234567890', '5.0',
            'Premium long-grain basmati rice', '', 'active'
          ],
          [
            'PROD-002', 'Sunflower Oil 1L', 'Edible Oils', 'PC',
            '15121110', '6', '130.00', '', '',
            '', '', 'active'
          ]
        ]

        csv_data = CSV.generate do |csv|
          csv << headers_row
          sample_rows.each { |row| csv << row }
        end

        response.headers['Content-Disposition'] = 'attachment; filename="sample_products.csv"'
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      # GET /api/v1/products/export_csv
      def export_csv
        authorize Product.new(organization: current_organization), :index?

        products = policy_scope(Product)
                     .includes(:product_category, :units_of_measure, :hsn_sac_code)
                     .order(name: :asc)
        products = products.search_sku_name(params[:q])       if params[:q].present?
        products = products.by_category(params[:category_id]) if params[:category_id].present?
        products = products.by_status(params[:status])        if params[:status].present?

        show_purchase_price = pundit_user.user
                                         &.membership_for(current_organization)
                                         &.role&.name&.in?(%w[owner admin])

        headers_row = %w[sku name category uom hsn_code gst_rate min_order_qty barcode
                         weight_kg description status]
        headers_row << 'purchase_price' if show_purchase_price

        csv_data = CSV.generate do |csv|
          csv << headers_row
          products.find_each do |p|
            row = [
              p.sku,
              p.name,
              p.product_category&.name,
              p.units_of_measure&.symbol,
              p.hsn_sac_code&.code,
              p.gst_rate,
              p.min_order_qty,
              p.barcode,
              p.weight_kg,
              p.description,
              p.status
            ]
            row << p.purchase_price if show_purchase_price
            csv << row
          end
        end

        filename = "products_#{current_organization.slug}_#{Date.current.iso8601}.csv"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      # POST /api/v1/products/:id/discontinue
      def discontinue
        authorize @product, :update?
        @product.update!(status: 'discontinued')
        render_success(serialize_product(@product))
      end

      # GET /api/v1/products/:id/price?branch_id=&retailer_id=&qty=
      def price
        authorize @product, :show?

        branch   = Branch.find_by!(id: params[:branch_id],   organization: current_organization)
        retailer = Customer.not_deleted.find_by(id: params[:retailer_id]) if params[:retailer_id].present?
        qty      = params[:qty].present? ? params[:qty].to_d : nil

        result = Pricing::EffectivePriceResolver.call(
          product:  @product,
          branch:   branch,
          retailer: retailer,
          qty:      qty
        )

        render_success({
          product_id:     @product.id,
          branch_id:      branch.id,
          retailer_id:    retailer&.id,
          qty:            qty,
          unit_price:     result.unit_price,
          source:         result.source,
          price_list_id:  result.price_list_id,
          discount_pct:   result.discount_pct,
          min_qty_matched: result.min_qty_matched,
          valid_from:     result.valid_from,
          valid_to:       result.valid_to
        })
      end

      private

      def set_product
        @product = current_organization.products.not_deleted.find(params[:id])
      end

      def product_params
        params.require(:product).permit(
          :sku, :name, :product_category_id, :units_of_measure_id,
          :hsn_sac_code_id, :gst_rate, :min_order_qty, :barcode,
          :purchase_price, :weight_kg, :status, :description, :image_url
        )
      end

      def serialize_product(product, detailed: false)
        data = {
          id:            product.id,
          sku:           product.sku,
          name:          product.name,
          gst_rate:      product.gst_rate,
          status:        product.status,
          min_order_qty: product.min_order_qty,
          barcode:       product.barcode,
          weight_kg:     product.weight_kg,
          image_url:     product.image_url,
          description:   product.description,
          hsn: {
            id:          product.hsn_sac_code_id,
            code:        product.hsn_sac_code&.code,
            code_type:   product.hsn_sac_code&.code_type,
            description: product.hsn_sac_code&.description,
            gst_rate:    product.hsn_sac_code&.gst_rate
          },
          category: {
            id:   product.product_category_id,
            name: product.product_category&.name
          },
          uom: {
            id:     product.units_of_measure_id,
            name:   product.units_of_measure&.name,
            symbol: product.units_of_measure&.symbol
          },
          created_at: product.created_at,
          updated_at: product.updated_at
        }

        if detailed
          # Only show purchase_price to owner/admin roles
          if pundit_user.user&.membership_for(current_organization)&.role&.name.in?(%w[owner admin])
            data[:purchase_price] = product.purchase_price
          end
        end

        data
      end
    end
  end
end
