require 'csv'

module Api
  module V1
    class PriceListItemsController < BaseController
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      before_action :require_organization!
      before_action :set_price_list
      before_action :set_item, only: %i[update destroy]

      # POST /api/v1/price_lists/:price_list_id/items
      def create
        authorize @price_list, :update?

        item = @price_list.items.new(item_params)

        if item.save
          render_created(serialize_item(item))
        else
          render_errors(item.errors.full_messages)
        end
      end

      # PATCH /api/v1/price_lists/:price_list_id/items/:id
      def update
        authorize @price_list, :update?

        if @item.update(item_params)
          render_success(serialize_item(@item))
        else
          render_errors(@item.errors.full_messages)
        end
      end

      # DELETE /api/v1/price_lists/:price_list_id/items/:id
      def destroy
        authorize @price_list, :update?
        @item.destroy!
        render_success({ message: 'Item removed from price list' })
      end

      # POST /api/v1/price_lists/:price_list_id/items/bulk_import
      # Expected CSV columns: sku, unit_price, min_qty (optional), discount_pct (optional)
      def bulk_import
        authorize @price_list, :update?

        unless params[:file].present?
          return render_errors(['file is required'], status: :bad_request)
        end

        results = { imported: [], failed: [] }

        require 'csv'
        csv_text = params[:file].read.force_encoding('UTF-8')
        csv      = CSV.parse(csv_text, headers: true, skip_blanks: true)

        ActiveRecord::Base.transaction do
          csv.each_with_index do |row, idx|
            line = idx + 2 # 1-based, accounting for header
            sku  = row['sku']&.strip&.upcase

            unless sku.present?
              results[:failed] << { line: line, sku: sku, error: 'sku is required' }
              next
            end

            product = current_organization.products.where(deleted_at: nil).find_by(sku: sku)
            unless product
              results[:failed] << { line: line, sku: sku, error: "product not found for SKU '#{sku}'" }
              next
            end

            unit_price   = row['unit_price']&.strip.to_f
            min_qty      = row['min_qty'].present?      ? row['min_qty'].strip.to_f      : nil
            discount_pct = row['discount_pct'].present? ? row['discount_pct'].strip.to_f : 0

            item = @price_list.items.find_or_initialize_by(
              product_id: product.id,
              min_qty:    min_qty
            )
            item.assign_attributes(unit_price: unit_price, discount_pct: discount_pct)

            if item.save
              results[:imported] << { line: line, sku: sku, action: item.previously_new_record? ? 'created' : 'updated' }
            else
              results[:failed] << { line: line, sku: sku, error: item.errors.full_messages.join(', ') }
            end
          end
        end

        render_success(
          imported_count: results[:imported].size,
          failed_count:   results[:failed].size,
          imported:       results[:imported],
          failed:         results[:failed],
          message:        "#{results[:imported].size} item(s) imported, #{results[:failed].size} failed"
        )
      rescue CSV::MalformedCSVError => e
        render_errors(["Invalid CSV format: #{e.message}"], status: :unprocessable_entity)
      end

      # GET /api/v1/price_lists/:price_list_id/items/sample_csv
      def sample_csv
        authorize @price_list, :update?

        # Pull up to 5 real product SKUs from the org so the sample is immediately usable
        sample_products = current_organization.products
                            .where(deleted_at: nil, status: 'active')
                            .order(:sku)
                            .limit(5)

        csv_data = CSV.generate do |csv|
          csv << %w[sku unit_price min_qty discount_pct]
          if sample_products.any?
            sample_products.each_with_index do |p, i|
              csv << [p.sku, '', i.zero? ? '' : '10', i.zero? ? '0' : '5']
            end
          else
            # Fallback placeholder rows when no products exist yet
            csv << ['YOUR-SKU-001', '100.00', '',   '0']
            csv << ['YOUR-SKU-002', '250.00', '',   '0']
            csv << ['YOUR-SKU-003', '250.00', '10', '5']
          end
        end

        response.headers['Content-Disposition'] =
          "attachment; filename=\"price_list_#{@price_list.id}_import_template.csv\""
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      # GET /api/v1/price_lists/:price_list_id/items/export_csv
      def export_csv
        authorize @price_list, :show?

        items = @price_list.items
                           .includes(:product)
                           .order('products.name')

        csv_data = CSV.generate do |csv|
          csv << %w[sku product_name unit_price min_qty discount_pct effective_price]
          items.each do |item|
            effective = item.unit_price * (1 - (item.discount_pct || 0) / 100.0)
            csv << [
              item.product&.sku,
              item.product&.name,
              item.unit_price,
              item.min_qty,
              item.discount_pct,
              effective.round(2)
            ]
          end
        end

        filename = "price_list_#{@price_list.id}_items_#{Date.current.iso8601}.csv"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      private

      def set_price_list
        @price_list = current_organization.price_lists.not_deleted.find(params[:price_list_id])
      end

      def set_item
        @item = @price_list.items.find(params[:id])
      end

      def item_params
        params.require(:price_list_item).permit(:product_id, :unit_price, :min_qty, :discount_pct)
      end

      def serialize_item(item)
        {
          id:            item.id,
          price_list_id: item.price_list_id,
          product_id:    item.product_id,
          product_sku:   item.product&.sku,
          product_name:  item.product&.name,
          unit_price:    item.unit_price,
          min_qty:       item.min_qty,
          discount_pct:  item.discount_pct
        }
      end
    end
  end
end
