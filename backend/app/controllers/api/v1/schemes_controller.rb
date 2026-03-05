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
        scope = scope.where("name ILIKE :q OR code ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        paginated = paginate(scope.by_priority.includes(:conditions, :rewards))
        render_success(paginated.map { |s| serialize(s) }, meta: pagination_meta(paginated))
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
        })
      end

      # GET /api/v1/schemes/:id
      def show
        authorize @scheme
        render_success(serialize(@scheme, detailed: true))
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
          render_created(serialize(scheme, detailed: true))
        else
          render_errors(scheme.errors.full_messages)
        end
      end

      # PATCH /api/v1/schemes/:id
      def update
        authorize @scheme

        if @scheme.update(scheme_params.except(:conditions, :rewards))
          persist_conditions_and_rewards(@scheme) if params[:scheme][:conditions] || params[:scheme][:rewards]
          render_success(serialize(@scheme, detailed: true))
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

      def serialize(scheme, detailed: false)
        h = {
          id:              scheme.id,
          code:            scheme.code,
          name:            scheme.name,
          scheme_type:     scheme.scheme_type,
          status:          scheme.status,
          applies_to:      scheme.applies_to,
          start_date:      scheme.start_date,
          end_date:        scheme.end_date,
          priority:        scheme.priority,
          exclusive:       scheme.exclusive,
          applicable_days: scheme.applicable_days,
          branch_id:        scheme.branch_id,
          notes:            scheme.notes,
          conditions_count: scheme.conditions.size,
          rewards_count:    scheme.rewards.size,
          reward_summary:   begin
            r = scheme.rewards.first
            if r
              case r.reward_type
              when 'percent_off'
                cap = r.max_reward_value ? " (max \u20b9#{r.max_reward_value.to_i})" : ''
                "#{r.reward_value.to_i}% off#{cap}"
              when 'amount_off'  then "\u20b9#{r.reward_value.to_i} off"
              when 'free_qty'    then "Free #{r.free_qty_per_trigger} per #{r.free_per_x}"
              when 'fixed_price' then "Fixed \u20b9#{r.reward_value.to_i}"
              end
            end
          end,
          created_at:       scheme.created_at&.strftime('%d %b %Y')
        }

        if detailed
          h[:conditions] = scheme.conditions.map { |c|
            { id: c.id, condition_type: c.condition_type, operator: c.operator, value: c.value }
          }
          h[:rewards] = scheme.rewards.map { |r|
            {
              id:                   r.id,
              reward_type:          r.reward_type,
              target_scope:         r.target_scope,
              target_product_id:    r.target_product_id,
              reward_value:         r.reward_value,
              max_reward_value:     r.max_reward_value,
              free_per_x:           r.free_per_x,
              free_qty_per_trigger: r.free_qty_per_trigger
            }
          }
        end

        h
      end
    end
  end
end
