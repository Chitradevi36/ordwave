module Api
  module V1
    class BeatSchedulesController < BaseController
      before_action :require_organization!
      before_action :set_beat
      before_action :set_schedule, only: %i[show retailers bulk_upsert update]

      def index
        schedules = @beat.beat_schedules.active.order(:weekday)
        authorize BeatSchedule.new(organization: current_organization)

        render_success(schedules.map { |s| serialize_schedule(s) })
      end

      def show
        render_success(serialize_schedule(@schedule, detailed: true))
      end

      def create
        authorize BeatSchedule.new(organization: current_organization)

        result = Beats::UpsertBeatScheduleService.new(
          beat:   @beat,
          params: schedule_params,
          actor:  current_user
        ).call

        if result.success?
          render_created(serialize_schedule(result.schedule))
        else
          render_errors(result.errors)
        end
      end

      def update
        authorize @schedule

        result = Beats::UpsertBeatScheduleService.new(
          beat:   @beat,
          params: schedule_params.merge(id: @schedule.id),
          actor:  current_user
        ).call

        if result.success?
          render_success(serialize_schedule(result.schedule))
        else
          render_errors(result.errors)
        end
      end

      def retailers
        authorize @schedule, :show?
        retailers = @schedule.beat_retailers.ordered.includes(:customer)
        render_success(retailers.map { |br| serialize_retailer(br) })
      end

      def bulk_upsert
        authorize @schedule, :update?

        retailers_params = params.permit(retailers: [:customer_id, :sequence_number, :visit_override, :notes])
                                 .fetch(:retailers, [])

        result = Beats::UpsertBeatRetailersService.new(
          schedule:         @schedule,
          retailers_params: retailers_params,
          actor:            current_user
        ).call

        if result.success?
          render_success({ count: result.retailers.size })
        else
          render_errors(result.errors)
        end
      end

      private

      def set_beat
        @beat = Beat.for_org(current_organization.id).find(params[:beat_id])
      end

      def set_schedule
        @schedule = @beat.beat_schedules.find(params[:id])
        authorize @schedule, :show?
      end

      def schedule_params
        params.require(:beat_schedule).permit(:sales_rep_id, :weekday, :start_time, :end_time, :active)
      end

      def serialize_schedule(s, detailed: false)
        data = {
          id:           s.id,
          beat_id:      s.beat_id,
          weekday:      s.weekday,
          weekday_name: s.weekday_name,
          sales_rep_id: s.sales_rep_id,
          start_time:   s.start_time,
          end_time:     s.end_time,
          active:       s.active
        }
        data[:retailers_count] = s.beat_retailers.count if detailed
        data
      end

      def serialize_retailer(br)
        {
          id:              br.id,
          customer_id:     br.customer_id,
          customer_name:   br.customer.name,
          customer_code:   br.customer.code,
          sequence_number: br.sequence_number,
          visit_override:  br.visit_override,
          notes:           br.notes
        }
      end
    end
  end
end
