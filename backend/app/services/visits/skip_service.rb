module Visits
  class SkipService
    Result = Struct.new(:success?, :visit_log, :errors)

    def initialize(params:, actor:, organization:, branch:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor        = actor
      @organization = organization
      @branch       = branch
    end

    def call
      visit_log = find_or_build_log

      unless %w[planned checked_in].include?(visit_log.visit_status)
        return Result.new(false, nil, ['Visit cannot be skipped in its current state'])
      end

      if visit_log.update(
           visit_status:     'skipped',
           skip_reason_code: @params[:skip_reason_code],
           notes:            @params[:notes] || visit_log.notes,
           gps_lat:          @params[:gps_lat] || visit_log.gps_lat,
           gps_lng:          @params[:gps_lng] || visit_log.gps_lng
         )
        AuditLog.create!(
          actor:        @actor,
          organization: @organization,
          auditable:    visit_log,
          action:       'visit_skipped',
          changes:      {
            customer_id:      visit_log.customer_id,
            skip_reason_code: visit_log.skip_reason_code
          }
        )
        Result.new(true, visit_log, [])
      else
        Result.new(false, nil, visit_log.errors.full_messages)
      end
    end

    private

    def find_or_build_log
      if @params[:visit_log_id]
        VisitLog.find(@params[:visit_log_id])
      else
        VisitLog.create!(
          organization:     @organization,
          branch:           @branch,
          sales_rep:        @actor,
          customer_id:      @params[:customer_id],
          route_id:         @params[:route_id],
          beat_schedule_id: @params[:beat_schedule_id],
          visit_date:       @params[:visit_date] || Date.current,
          visit_status:     'planned',
          idempotency_key:  @params[:idempotency_key]
        )
      end
    end
  end
end
