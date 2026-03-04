module Api
  module V1
    class ProductCategoriesController < BaseController
      before_action :require_organization!
      before_action :set_category, only: %i[show update destroy]
      skip_after_action :verify_policy_scoped, only: :index

      # GET /api/v1/product_categories
      def index
        categories = current_organization.product_categories
                                         .not_deleted
                                         .order(name: :asc)
        categories = categories.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
        paginated  = paginate(categories)
        authorize ProductCategory.new(organization: current_organization), :index?
        render_success(
          paginated.map { |c| serialize_category(c) },
          meta: pagination_meta(paginated)
        )
      end

      # GET /api/v1/product_categories/:id
      def show
        authorize @category
        render_success(serialize_category(@category))
      end

      # POST /api/v1/product_categories
      def create
        authorize ProductCategory.new(organization: current_organization)

        category = current_organization.product_categories.build(category_params)
        if category.save
          render_created(serialize_category(category))
        else
          render_errors(category.errors.full_messages)
        end
      end

      # PATCH /api/v1/product_categories/:id
      def update
        authorize @category

        if @category.update(category_params)
          render_success(serialize_category(@category))
        else
          render_errors(@category.errors.full_messages)
        end
      end

      # DELETE /api/v1/product_categories/:id
      def destroy
        authorize @category

        if @category.products.exists?
          return render_errors(
            ["Category '#{@category.name}' has products — reassign them before deleting."],
            status: :unprocessable_entity
          )
        end

        @category.soft_delete!
        render_success({ message: 'Category deleted' })
      end

      private

      def set_category
        @category = current_organization.product_categories.not_deleted.find(params[:id])
      end

      def category_params
        params.require(:product_category).permit(:name, :code, :active)
      end

      def serialize_category(category)
        {
          id:           category.id,
          name:         category.name,
          code:         category.code,
          active:       category.active,
          product_count: category.products.not_deleted.count,
          created_at:   category.created_at,
          updated_at:   category.updated_at
        }
      end
    end
  end
end
