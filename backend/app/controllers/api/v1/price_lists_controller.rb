module Api
  module V1
    class PriceListsController < BaseController
      before_action :require_organization!
      before_action :set_price_list, only: %i[show update destroy assign unassign items]

      # GET /api/v1/price_lists
      def index
        price_lists = policy_scope(PriceList)
                        .not_deleted
                        .includes(:branch, items: :product)
                        .order(created_at: :desc)

        price_lists = price_lists.where(list_type: params[:list_type]) if params[:list_type].present?
        price_lists = price_lists.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        price_lists = price_lists.active_lists                          if params[:active].present?
        paginated   = paginate(price_lists)

        render_success(
          paginated.map { |pl| serialize_price_list(pl) },
          meta: pagination_meta(paginated)
        )
      end

      # GET /api/v1/price_lists/:id
      def show
        authorize @price_list
        render_success(serialize_price_list(@price_list, detailed: true))
      end

      # POST /api/v1/price_lists
      def create
        authorize PriceList.new(organization: current_organization)

        price_list = current_organization.price_lists.new(price_list_params)

        if price_list.save
          render_created(serialize_price_list(price_list, detailed: true))
        else
          render_errors(price_list.errors.full_messages)
        end
      end

      # PATCH /api/v1/price_lists/:id
      def update
        authorize @price_list

        if @price_list.update(price_list_params)
          render_success(serialize_price_list(@price_list, detailed: true))
        else
          render_errors(@price_list.errors.full_messages)
        end
      end

      # DELETE /api/v1/price_lists/:id
      def destroy
        authorize @price_list
        @price_list.soft_delete!
        render_success({ message: 'Price list deleted' })
      end

      # POST /api/v1/price_lists/:id/assign
      # Assigns a price list to a retailer or a retailer tier or makes it the branch standard.
      # Body: { assign_to: 'retailer'|'tier'|'branch_standard',
      #         customer_id:, retailer_tier:, starts_on:, ends_on: }
      def assign
        authorize @price_list, :assign?

        result = PriceLists::AssignService.new(
          price_list: @price_list,
          params:     assign_params
        ).call

        if result.success?
          render_success({ message: 'Price list assigned', assignment: serialize_assignment(result.record) })
        else
          render_errors(result.errors)
        end
      end

      # DELETE /api/v1/price_lists/:id/unassign
      # Body: { assign_to: 'retailer'|'tier'|'branch_standard',
      #         customer_id:, retailer_tier: }
      def unassign
        authorize @price_list, :unassign?

        case assign_params[:assign_to]
        when 'retailer'
          assignment = @price_list.retailer_assignments.active.find_by!(
            customer_id: assign_params[:customer_id]
          )
          assignment.update!(active: false)
        when 'tier'
          assignment = @price_list.tier_assignments.active.find_by!(
            retailer_tier: assign_params[:retailer_tier]
          )
          assignment.update!(active: false)
        else
          render_errors(['Invalid assign_to value'])
          return
        end

        render_success({ message: 'Price list unassigned' })
      end

      # GET /api/v1/price_lists/:id/items
      def items
        authorize @price_list, :show?
        items = @price_list.items.includes(:product).order('products.name')
        render_success(items.map { |item| serialize_item(item) })
      end

      private

      def set_price_list
        @price_list = current_organization.price_lists.not_deleted.find(params[:id])
      end

      def price_list_params
        params.require(:price_list).permit(
          :name, :list_type, :branch_id, :valid_from, :valid_to
        )
      end

      def assign_params
        params.permit(:assign_to, :customer_id, :retailer_tier, :starts_on, :ends_on)
      end

      def serialize_price_list(pl, detailed: false)
        data = {
          id:         pl.id,
          name:       pl.name,
          list_type:  pl.list_type,
          valid_from: pl.valid_from,
          valid_to:   pl.valid_to,
          branch: pl.branch ? { id: pl.branch_id, name: pl.branch.name } : nil,
          items_count: pl.items.size,
          created_at:  pl.created_at,
          updated_at:  pl.updated_at
        }

        if detailed
          data[:items] = pl.items.includes(:product).map { |item| serialize_item(item) }
        end

        data
      end

      def serialize_item(item)
        {
          id:           item.id,
          product_id:   item.product_id,
          product_sku:  item.product&.sku,
          product_name: item.product&.name,
          unit_price:   item.unit_price,
          min_qty:      item.min_qty,
          discount_pct: item.discount_pct
        }
      end

      def serialize_assignment(record)
        case record
        when RetailerPriceListAssignment
          {
            type:        'retailer',
            customer_id: record.customer_id,
            starts_on:   record.starts_on,
            ends_on:     record.ends_on,
            active:      record.active
          }
        when TierPriceListAssignment
          {
            type:          'tier',
            retailer_tier: record.retailer_tier,
            branch_id:     record.branch_id,
            starts_on:     record.starts_on,
            ends_on:       record.ends_on,
            active:        record.active
          }
        else
          {}
        end
      end
    end
  end
end
