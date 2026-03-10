module Api
  module V1
    class VisitsController < BaseController
      before_action :require_organization!

      # today, checkin, skip_new are open to any authenticated org member —
      # skip Pundit's verify_authorized check (no policy decision required).
      skip_after_action :verify_authorized, only: %i[today checkin skip_new]

      # GET /api/v1/visits/today
      def today
        branch = current_organization.branches.find_by(id: params[:branch_id]) ||
                 current_organization.branches.first

        result = Visits::GetTodaysPlanService.new(
          sales_rep: current_user,
          branch:    branch,
          date:      params[:date]&.then { |d| Date.parse(d) } || Date.current
        ).call

        render_success(serialize_plan(result.plan))
      end

      # POST /api/v1/visits/checkin
      def checkin
        result = Visits::CheckinService.new(
          params:       checkin_params,
          actor:        current_user,
          organization: current_organization,
          branch:       resolve_branch
        ).call

        if result.success?
          render_created(serialize_log(result.visit_log))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/visits/:id/checkout
      def checkout
        log = VisitLog.where(organization: current_organization, sales_rep: current_user)
                      .find(params[:id])
        authorize log, :update?

        result = Visits::CheckoutService.new(
          visit_log: log,
          params:    checkout_params,
          actor:     current_user
        ).call

        if result.success?
          render_success(serialize_log(result.visit_log))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/visits/:id/skip
      def skip
        log = VisitLog.where(organization: current_organization).find(params[:id])
        authorize log, :skip?

        result = Visits::SkipService.new(
          params:       skip_params.merge(visit_log_id: log.id),
          actor:        current_user,
          organization: current_organization,
          branch:       log.branch
        ).call

        if result.success?
          render_success(serialize_log(result.visit_log))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/visits/skip_new  (skip without an existing log)
      def skip_new
        result = Visits::SkipService.new(
          params:       skip_params,
          actor:        current_user,
          organization: current_organization,
          branch:       resolve_branch
        ).call

        if result.success?
          render_success(serialize_log(result.visit_log))
        else
          render_errors(result.errors)
        end
      end

      # GET /api/v1/visits
      def index
        scope = policy_scope(VisitLog).order(visit_date: :desc, created_at: :desc)
        scope = scope.for_date(params[:date])     if params[:date].present?
        scope = scope.for_rep(params[:rep_id])    if params[:rep_id].present?
        scope = scope.for_customer(params[:customer_id]) if params[:customer_id].present?
        scope = scope.where(visit_status: params[:status]) if params[:status].present?
        logs  = paginate(scope)

        render_success(logs.map { |l| serialize_log(l) }, meta: pagination_meta(logs))
      end

      private

      def resolve_branch
        current_organization.branches.find(checkin_params[:branch_id] || params[:branch_id])
      rescue ActiveRecord::RecordNotFound
        current_organization.branches.first
      end

      def checkin_params
        params.permit(:customer_id, :route_id, :beat_schedule_id, :visit_date,
                      :checkin_at, :gps_lat, :gps_lng, :device_id, :idempotency_key, :branch_id)
      end

      def checkout_params
        params.permit(:checkout_at, :notes, :gps_lat, :gps_lng)
      end

      def skip_params
        params.permit(:customer_id, :route_id, :beat_schedule_id, :visit_date,
                      :skip_reason_code, :notes, :gps_lat, :gps_lng, :idempotency_key, :branch_id)
      end

      def serialize_plan(plan)
        plan.map do |entry|
          {
            schedule: {
              id:           entry[:schedule].id,
              weekday:      entry[:schedule].weekday,
              weekday_name: entry[:schedule].weekday_name,
              beat_id:      entry[:schedule].beat_id,
              beat_name:    entry[:schedule].beat.name
            },
            customers: entry[:customers].map do |c|
              {
                customer_id:   c[:customer].id,
                customer_name: c[:customer].name,
                customer_code: c[:customer].code,
                phone:         c[:customer].phone,
                due:           c[:due],
                due_reason:    c[:due_reason],
                override:      c[:override],
                last_visited_at: c[:customer].last_visited_at,
                next_due_on:     c[:customer].next_due_on,
                sequence:        c[:sequence]
              }
            end
          }
        end
      end

      def serialize_log(log)
        {
          id:               log.id,
          customer_id:      log.customer_id,
          customer_name:    log.customer.name,
          visit_date:       log.visit_date,
          visit_status:     log.visit_status,
          checkin_at:       log.checkin_at,
          checkout_at:      log.checkout_at,
          duration_minutes: log.duration_minutes,
          skip_reason_code: log.skip_reason_code,
          gps_lat:          log.gps_lat,
          gps_lng:          log.gps_lng,
          notes:            log.notes
        }
      end
    end
  end
end
