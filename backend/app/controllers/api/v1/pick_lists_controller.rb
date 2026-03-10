module Api
  module V1
    class PickListsController < BaseController
      before_action :require_organization!
      before_action :set_pick_list, only: %i[show start update_item complete]

      # GET /api/v1/pick_lists
      def index
        scope = policy_scope(PickList)
        scope = scope.by_status(params[:status])          if params[:status].present?
        scope = scope.by_branch(params[:branch_id])       if params[:branch_id].present?
        scope = scope.where(picker_id: params[:picker_id]) if params[:picker_id].present?

        scope  = scope.includes(:branch, :sales_order, :picker, pick_list_items: :product)
                      .order(created_at: :desc)
        lists  = paginate(scope)

        render_success(
          lists.map { |pl| serialize_pick_list(pl) },
          meta: pagination_meta(lists)
        )
      end

      # GET /api/v1/pick_lists/:id
      def show
        authorize @pick_list
        render_success(serialize_pick_list(@pick_list, detailed: true))
      end

      # POST /api/v1/pick_lists/:id/start
      def start
        authorize @pick_list, :update?
        @pick_list.start!(current_user)
        render_success(serialize_pick_list(@pick_list, detailed: true))
      rescue RuntimeError => e
        render_errors([e.message])
      end

      # PATCH /api/v1/pick_lists/:id/items/:item_id
      def update_item
        authorize @pick_list, :update?
        item = @pick_list.pick_list_items.find(params[:item_id])
        qty  = params.dig(:item, :qty_picked).to_i
        item.pick!(qty)
        render_success(serialize_pick_list(@pick_list.reload, detailed: true))
      rescue ActiveRecord::RecordNotFound
        render json: { errors: ['Item not found'] }, status: :not_found
      rescue ArgumentError => e
        render_errors([e.message])
      end

      # POST /api/v1/pick_lists/:id/complete
      def complete
        authorize @pick_list, :update?
        @pick_list.complete!
        render_success(serialize_pick_list(@pick_list, detailed: true))
      rescue RuntimeError => e
        render_errors([e.message])
      end

      private

      def set_pick_list
        @pick_list = policy_scope(PickList).includes(:branch, :sales_order, :picker, pick_list_items: :product)
                                           .find(params[:id])
      end

      def serialize_pick_list(pl, detailed: false)
        data = {
          id:          pl.id,
          pick_number: pl.pick_number,
          status:      pl.status,
          started_at:  pl.started_at,
          completed_at: pl.completed_at,
          created_at:  pl.created_at,
          total_items: pl.total_items,
          picked_items: pl.picked_items,
          branch: {
            id:   pl.branch_id,
            name: pl.branch&.name
          },
          sales_order: {
            id:           pl.sales_order_id,
            order_number: pl.sales_order&.order_number,
            customer_name: pl.sales_order&.customer&.name
          },
          picker: pl.picker ? { id: pl.picker_id, name: pl.picker&.full_name } : nil
        }

        if detailed
          data[:items] = pl.pick_list_items.map do |item|
            {
              id:            item.id,
              product_id:    item.product_id,
              product_name:  item.product&.name,
              product_sku:   item.product&.sku,
              bin_location:  item.bin_location,
              qty_requested: item.qty_requested,
              qty_picked:    item.qty_picked,
              picked_at:     item.picked_at,
              fulfilled:     item.fulfilled?
            }
          end
        end

        data
      end
    end
  end
end
