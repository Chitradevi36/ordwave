module Api
  module V1
    # Trade promotions / Scheme Engine management
    #
    # GET    /api/v1/schemes            — list
    # GET    /api/v1/schemes/:id        — show
    # POST   /api/v1/schemes            — create
    # PATCH  /api/v1/schemes/:id        — update
    # DELETE /api/v1/schemes/:id        — deactivate
    #
    class SchemesController < BaseController
      before_action :require_organization!
      before_action :set_scheme, only: %i[show update destroy]

      # GET /api/v1/schemes
      def index
        scope = policy_scope(Scheme)
        scope = scope.where(scheme_type: params[:scheme_type]) if params[:scheme_type].present?
        scope = scope.where(status: params[:status])           if params[:status].present?
        scope = scope.where(branch_id: params[:branch_id])     if params[:branch_id].present?
        scope = scope.involving_product(params[:product_id])   if params[:product_id].present?
        scope = scope.where("name ILIKE :q OR code ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        paginated = paginate(scope.by_priority.includes(:conditions, :rewards))
        # Batch-load product names for the list (products_preview)
        all_pids = paginated.flat_map(&:all_referenced_product_ids).uniq
        product_map = all_pids.any? ? Product.where(id: all_pids).index_by(&:id) : {}
        render_success(paginated.map { |s| serialize(s, product_map: product_map) }, meta: pagination_meta(paginated))
      end

      # GET /api/v1/schemes/stats
      def stats
        authorize Scheme.new(organization: current_organization), :index?
        scope = policy_scope(Scheme)
        today = Date.current
        render_success({
          total:         scope.count,
          active:        scope.where(status: 'active').count,
          inactive:      scope.where(status: 'inactive').count,
          expired:       scope.where(status: 'expired').count,
          expiring_soon: scope.where(status: 'active')
                              .where('end_date IS NOT NULL AND end_date BETWEEN ? AND ?', today, today + 7).count,
          exclusive:     scope.where(exclusive: true).count,
          evergreen:     scope.where(status: 'active', end_date: nil).count,
          by_type:       Scheme::TYPES.index_with { |t| scope.where(scheme_type: t).count },
        })
      end

      # GET /api/v1/schemes/by_product?product_id=X
      # Returns all schemes whose conditions or rewards reference a specific product.
      def by_product
        authorize Scheme.new(organization: current_organization), :index?
        product = Product.for_org(current_organization.id).find(params[:product_id])
        schemes  = policy_scope(Scheme)
                     .involving_product(product.id)
                     .includes(:conditions, :rewards)
                     .by_priority
        all_pids = schemes.flat_map(&:all_referenced_product_ids).uniq
        product_map = all_pids.any? ? Product.where(id: all_pids).index_by(&:id) : {}
        render_success({
          product: { id: product.id, name: product.name, sku: product.sku },
          schemes: schemes.map { |s| serialize(s, detailed: true, product_map: product_map) }
        })
      rescue ActiveRecord::RecordNotFound
        render_not_found('Product')
      end

      # GET /api/v1/schemes/:id
      def show
        authorize @scheme
        all_pids    = @scheme.all_referenced_product_ids
        product_map = all_pids.any? ? Product.where(id: all_pids).index_by(&:id) : {}
        render_success(serialize(@scheme, detailed: true, product_map: product_map))
      end

      # POST /api/v1/schemes
      def create
        authorize Scheme.new(organization: current_organization)

        scheme = Scheme.new(
          scheme_params.except(:conditions, :rewards)
                       .merge(organization: current_organization,
                              created_by:   current_user)
        )

        if scheme.save
          persist_conditions_and_rewards(scheme)
          all_pids    = scheme.all_referenced_product_ids
          product_map = all_pids.any? ? Product.where(id: all_pids).index_by(&:id) : {}
          render_created(serialize(scheme, detailed: true, product_map: product_map))
        else
          render_errors(scheme.errors.full_messages)
        end
      end

      # PATCH /api/v1/schemes/:id
      def update
        authorize @scheme

        if @scheme.update(scheme_params.except(:conditions, :rewards))
          persist_conditions_and_rewards(@scheme) if params[:scheme][:conditions] || params[:scheme][:rewards]
          all_pids    = @scheme.all_referenced_product_ids
          product_map = all_pids.any? ? Product.where(id: all_pids).index_by(&:id) : {}
          render_success(serialize(@scheme, detailed: true, product_map: product_map))
        else
          render_errors(@scheme.errors.full_messages)
        end
      end

      # DELETE /api/v1/schemes/:id  — soft deactivate
      def destroy
        authorize @scheme
        @scheme.update!(status: 'inactive')
        render_success({ message: 'Scheme deactivated' })
      end

      private

      def set_scheme
        @scheme = Scheme
                    .where(organization: current_organization)
                    .includes(:conditions, :rewards)
                    .find(params[:id])
      end

      def persist_conditions_and_rewards(scheme)
        if params.dig(:scheme, :conditions)
          scheme.conditions.destroy_all
          Array(params[:scheme][:conditions]).each do |c|
            scheme.conditions.create!(
              condition_type: c[:condition_type],
              operator:       c[:operator] || '>=',
              value:          c[:value] || {}
            )
          end
        end

        if params.dig(:scheme, :rewards)
          scheme.rewards.destroy_all
          Array(params[:scheme][:rewards]).each do |r|
            scheme.rewards.create!(
              reward_type:          r[:reward_type],
              target_scope:         r[:target_scope] || 'order',
              target_product_id:    r[:target_product_id],
              reward_value:         r[:reward_value],
              max_reward_value:     r[:max_reward_value],
              free_per_x:           r[:free_per_x],
              free_qty_per_trigger: r[:free_qty_per_trigger]
            )
          end
        end
      end

      def scheme_params
        params.require(:scheme).permit(
          :code, :name, :description, :scheme_type, :status,
          :branch_id, :start_date, :end_date, :priority, :exclusive,
          :applies_to,
          applicable_days: []
        )
      end

      # product_map: Hash<id => Product> — pass in from caller to avoid N+1
      def serialize(scheme, detailed: false, product_map: {})
        r = scheme.rewards.first
        reward_summary = if r
          case r.reward_type
          when 'percent_off'
            cap = r.max_reward_value ? " (max \u20b9#{r.max_reward_value.to_i})" : ''
            "#{r.reward_value.to_i}% off#{cap}"
          when 'amount_off'  then "\u20b9#{r.reward_value.to_i} off"
          when 'free_qty'
            prod = r.target_product_id ? product_map[r.target_product_id] : nil
            prod_label = prod ? " #{prod.sku}" : ''
            "Free #{r.free_qty_per_trigger} per #{r.free_per_x}#{prod_label}"
          when 'fixed_price' then "Fixed \u20b9#{r.reward_value.to_i}"
          end
        end

        # Products preview for list rows: first 3 product names from product_inclusion conditions
        preview_pids = scheme.conditions
                             .select { |c| c.condition_type == 'product_inclusion' }
                             .flat_map { |c| Array(c.value['product_ids']).map(&:to_i) }
                             .uniq.first(3)
        products_preview = preview_pids.map do |pid|
          p = product_map[pid]
          p ? { id: p.id, name: p.name, sku: p.sku } : { id: pid, name: nil, sku: nil }
        end

        h = {
          id:               scheme.id,
          code:             scheme.code,
          name:             scheme.name,
          scheme_type:      scheme.scheme_type,
          status:           scheme.status,
          applies_to:       scheme.applies_to,
          start_date:       scheme.start_date,
          end_date:         scheme.end_date,
          priority:         scheme.priority,
          exclusive:        scheme.exclusive,
          applicable_days:  scheme.applicable_days,
          branch_id:        scheme.branch_id,
          notes:            scheme.notes,
          conditions_count: scheme.conditions.size,
          rewards_count:    scheme.rewards.size,
          reward_summary:   reward_summary,
          products_preview: products_preview,   # [{id, name, sku}, …]
          created_at:       scheme.created_at&.strftime('%d %b %Y')
        }

        if detailed
          h[:conditions] = scheme.conditions.map do |c|
            cond = { id: c.id, condition_type: c.condition_type, operator: c.operator, value: c.value }
            if %w[product_inclusion product_exclusion].include?(c.condition_type)
              pids = Array(c.value['product_ids']).map(&:to_i)
              cond[:products] = pids.map do |pid|
                p = product_map[pid]
                p ? { id: p.id, name: p.name, sku: p.sku } : { id: pid, name: nil, sku: nil }
              end
            end
            cond
          end

          h[:rewards] = scheme.rewards.map do |rw|
            target_prod = rw.target_product_id ? product_map[rw.target_product_id] : nil
            {
              id:                   rw.id,
              reward_type:          rw.reward_type,
              target_scope:         rw.target_scope,
              target_product_id:    rw.target_product_id,
              target_product:       target_prod ? { id: target_prod.id, name: target_prod.name, sku: target_prod.sku } : nil,
              reward_value:         rw.reward_value,
              max_reward_value:     rw.max_reward_value,
              free_per_x:           rw.free_per_x,
              free_qty_per_trigger: rw.free_qty_per_trigger
            }
          end
        end

        h
      end
    end
  end
end
