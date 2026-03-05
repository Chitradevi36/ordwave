module Api
  module V1
    class BeatsController < BaseController
      before_action :require_organization!
      before_action :set_beat, only: %i[show update]

      def index
        scope = policy_scope(Beat)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.where(route_id: params[:route_id])   if params[:route_id].present?
        scope = filter_by_query(scope)                     if params[:q].present?
        beats = paginate(scope.order(:name))

        render_success(beats.map { |b| serialize_beat(b) }, meta: pagination_meta(beats))
      end

      def show
        render_success(serialize_beat(@beat, detailed: true))
      end

      def create
        authorize Beat.new(organization: current_organization)

        branch_id = params.dig(:beat, :branch_id).presence ||
                    current_organization.branches.first&.id

        result = Beats::CreateBeatService.new(
          params:       beat_params,
          actor:        current_user,
          organization: current_organization,
          branch_id:    branch_id
        ).call

        if result.success?
          render_created(serialize_beat(result.beat))
        else
          render_errors(result.errors)
        end
      end

      def update
        authorize @beat

        if @beat.update(beat_params.except(:code))
          AuditLog.create!(
            actor:        current_user,
            organization: current_organization,
            auditable:    @beat,
            action:       'beat_updated',
            changes:      beat_params.to_h
          )
          render_success(serialize_beat(@beat))
        else
          render_errors(@beat.errors.full_messages)
        end
      end

      private

      def set_beat
        @beat = Beat.for_org(current_organization.id).find(params[:id])
        authorize @beat
      end

      def beat_params
        params.require(:beat).permit(:name, :code, :route_id, :branch_id, :notes, :active)
      end

      def filter_by_query(scope)
        q = "%#{params[:q].strip}%"
        scope.where('beats.name ILIKE :q OR beats.code ILIKE :q', q: q)
      end

      def serialize_beat(beat, detailed: false)
        data = {
          id:        beat.id,
          name:      beat.name,
          code:      beat.code,
          active:    beat.active,
          notes:     beat.notes,
          branch_id: beat.branch_id,
          route_id:  beat.route_id,
          route_name: beat.route&.name,
          created_by_id: beat.created_by_id
        }
        if detailed
          data[:schedules] = beat.beat_schedules.active.map { |s| serialize_schedule_brief(s) }
        end
        data
      end

      def serialize_schedule_brief(s)
        {
          id:           s.id,
          weekday:      s.weekday,
          weekday_name: s.weekday_name,
          sales_rep_id: s.sales_rep_id,
          active:       s.active
        }
      end
    end
  end
end
