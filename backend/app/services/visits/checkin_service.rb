module Visits
  class CheckinService
    Result = Struct.new(:success?, :visit_log, :errors)

    def initialize(params:, actor:, organization:, branch:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor        = actor
      @organization = organization
      @branch       = branch
    end

    def call
      # Idempotency: return existing record if key already used
      if @params[:idempotency_key].present?
        existing = VisitLog.find_by(idempotency_key: @params[:idempotency_key])
        return Result.new(true, existing, []) if existing
      end

      log = VisitLog.new(
        organization:     @organization,
        branch:           @branch,
        sales_rep:        @actor,
        customer_id:      @params[:customer_id],
        route_id:         @params[:route_id],
        beat_schedule_id: @params[:beat_schedule_id],
        visit_date:       @params[:visit_date] || Date.current,
        checkin_at:       @params[:checkin_at] || Time.current,
        gps_lat:          @params[:gps_lat],
        gps_lng:          @params[:gps_lng],
        device_id:        @params[:device_id],
        idempotency_key:  @params[:idempotency_key],
        visit_status:     'checked_in'
      )

      if log.save
        AuditLog.create!(
          actor:        @actor,
          organization: @organization,
          auditable:    log,
          action:       'visit_checked_in',
          changes:      { customer_id: log.customer_id, visit_date: log.visit_date }
        )
        Result.new(true, log, [])
      else
        Result.new(false, nil, log.errors.full_messages)
      end
    end
  end
end
