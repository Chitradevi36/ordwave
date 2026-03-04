module Api
  module V1
    class UnitsOfMeasureController < BaseController
      before_action :require_organization!
      before_action :set_uom, only: %i[show update destroy]
      skip_after_action :verify_policy_scoped, only: :index

      # GET /api/v1/units_of_measure
      def index
        authorize UnitsOfMeasure.new, :index?
        uoms = UnitsOfMeasure.order(name: :asc)
        uoms = uoms.where("name ILIKE :q OR symbol ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
        uoms = uoms.active if params[:active].present?
        paginated = paginate(uoms)
        render_success(
          paginated.map { |u| serialize_uom(u) },
          meta: pagination_meta(paginated)
        )
      end

      # GET /api/v1/units_of_measure/:id
      def show
        authorize @uom
        render_success(serialize_uom(@uom))
      end

      # POST /api/v1/units_of_measure
      def create
        authorize UnitsOfMeasure.new

        uom = UnitsOfMeasure.new(uom_params)
        if uom.save
          render_created(serialize_uom(uom))
        else
          render_errors(uom.errors.full_messages)
        end
      end

      # PATCH /api/v1/units_of_measure/:id
      def update
        authorize @uom

        if @uom.update(uom_params)
          render_success(serialize_uom(@uom))
        else
          render_errors(@uom.errors.full_messages)
        end
      end

      # DELETE /api/v1/units_of_measure/:id
      def destroy
        authorize @uom

        if @uom.products.exists?
          return render_errors(
            ["UOM '#{@uom.symbol}' is in use — reassign products before deleting."],
            status: :unprocessable_entity
          )
        end

        @uom.destroy!
        render_success({ message: 'Unit of measure deleted' })
      end

      private

      def set_uom
        @uom = UnitsOfMeasure.find(params[:id])
      end

      def uom_params
        params.require(:units_of_measure).permit(:name, :symbol, :active)
      end

      def serialize_uom(uom)
        {
          id:            uom.id,
          name:          uom.name,
          symbol:        uom.symbol,
          active:        uom.active,
          product_count: uom.products.not_deleted.count,
          created_at:    uom.created_at,
          updated_at:    uom.updated_at
        }
      end
    end
  end
end
