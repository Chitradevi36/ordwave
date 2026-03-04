module Api
  module V1
    class PrepaymentSkusController < BaseController
      before_action :require_organization!
      before_action :set_prepayment_sku, only: %i[show deactivate]

      # GET /api/v1/prepayment_skus
      def index
        skus = policy_scope(PrepaymentSku)
                 .includes(:product, :branch, :created_by)
                 .order(created_at: :desc)

        skus = skus.for_branch(params[:branch_id]) if params[:branch_id].present?
        skus = skus.where(active: params[:active] == 'true') if params[:active].present?

        paginated = paginate(skus)
        render_success(paginated.map { |s| serialize(s) }, meta: pagination_meta(paginated))
      end

      # GET /api/v1/prepayment_skus/:id
      def show
        authorize @sku
        render_success(serialize(@sku))
      end

      # POST /api/v1/prepayment_skus
      def create
        sku = PrepaymentSku.new(prepayment_sku_params.merge(
          organization:  current_organization,
          created_by:    current_user
        ))
        authorize sku

        if sku.save
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    sku,
            action:       'prepayment_sku_added',
            changes:      { product_id: sku.product_id, branch_id: sku.branch_id }
          )
          render_created(serialize(sku))
        else
          render_errors(sku.errors.full_messages)
        end
      end

      # DELETE /api/v1/prepayment_skus/:id  (soft deactivation)
      def deactivate
        authorize @sku, :destroy?

        @sku.deactivate!
        Credit::AuditLogger.log(
          actor:        current_user,
          organization: current_organization,
          auditable:    @sku,
          action:       'prepayment_sku_deactivated',
          changes:      { product_id: @sku.product_id, branch_id: @sku.branch_id },
          reason:       params[:reason]
        )
        render_success({ message: 'Prepayment SKU deactivated' })
      end

      private

      def set_prepayment_sku
        @sku = PrepaymentSku.where(organization: current_organization).find(params[:id])
      end

      def prepayment_sku_params
        params.require(:prepayment_sku).permit(:product_id, :branch_id, :reason, :effective_from)
      end

      def serialize(s)
        {
          id:             s.id,
          product_id:     s.product_id,
          product_name:   s.product&.name,
          product_sku:    s.product&.sku,
          branch_id:      s.branch_id,
          branch_name:    s.branch&.name,
          reason:         s.reason,
          effective_from: s.effective_from,
          active:         s.active,
          created_by:     s.created_by&.full_name,
          created_at:     s.created_at
        }
      end
    end
  end
end
