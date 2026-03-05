module Beats
  class UpsertBeatScheduleService
    Result = Struct.new(:success?, :schedule, :errors)

    def initialize(beat:, params:, actor:)
      @beat   = beat
      @params = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor  = actor
    end

    def call
      schedule = existing_schedule || BeatSchedule.new

      is_new = schedule.new_record?

      schedule.assign_attributes(
        beat:         @beat,
        organization: @beat.organization,
        branch:       @beat.branch,
        sales_rep_id: @params[:sales_rep_id],
        weekday:      @params[:weekday],
        start_time:   @params[:start_time],
        end_time:     @params[:end_time],
        active:       @params.fetch(:active, true)
      )

      if schedule.save
        action = is_new ? 'beat_schedule_created' : 'beat_schedule_updated'
        AuditLog.create!(
          actor:        @actor,
          organization: @beat.organization,
          auditable:    schedule,
          action:       action,
          changes:      { weekday: schedule.weekday, sales_rep_id: schedule.sales_rep_id }
        )
        Result.new(true, schedule, [])
      else
        Result.new(false, nil, schedule.errors.full_messages)
      end
    end

    private

    def existing_schedule
      if @params[:id]
        @beat.beat_schedules.find_by(id: @params[:id])
      else
        # Fall back to uniqueness key so we update rather than fail on duplicate
        BeatSchedule.find_by(
          sales_rep_id: @params[:sales_rep_id],
          branch_id:    @beat.branch_id,
          weekday:      @params[:weekday]
        )
      end
    end
  end
end
