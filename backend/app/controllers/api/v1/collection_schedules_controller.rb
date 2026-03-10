module Api
  module V1
    class CollectionSchedulesController < BaseController
      before_action :require_organization!
      before_action :set_schedule, only: %i[show update complete skip reschedule]

      SCHEDULE_INCLUDES = [
        :customer,
        :branch,
        :assigned_to,
        :completed_payment
      ].freeze

      # ── GET /api/v1/collection_schedules ───────────────────────────────────
      def index
        base  = policy_scope(CollectionSchedule).includes(SCHEDULE_INCLUDES)
        base  = apply_filters(base)
        items = paginate(base.order(scheduled_date: :asc, created_at: :asc))

        counts = policy_scope(CollectionSchedule).group(:status).count

        render_success(
          items.map { |s| serialize_schedule(s) },
          meta: pagination_meta(items).merge(counts: counts)
        )
      end

      # ── GET /api/v1/collection_schedules/:id ───────────────────────────────
      def show
        authorize @schedule
        render_success(serialize_schedule(@schedule))
      end

      # ── POST /api/v1/collection_schedules ─────────────────────────────────
      def create
        schedule = CollectionSchedule.new(schedule_params)
        schedule.organization = current_organization
        authorize schedule

        if schedule.save
          render_created(serialize_schedule(schedule))
        else
          render_errors(schedule.errors.full_messages)
        end
      end

      # ── PATCH /api/v1/collection_schedules/:id ────────────────────────────
      def update
        authorize @schedule
        if @schedule.update(schedule_params)
          render_success(serialize_schedule(@schedule))
        else
          render_errors(@schedule.errors.full_messages)
        end
      end

      # ── POST /api/v1/collection_schedules/:id/complete ─────────────────────
      def complete
        authorize @schedule, :complete?

        payment = Payment
                    .for_org(current_organization)
                    .find_by(id: params[:payment_id])

        unless payment
          return render_errors(["Payment not found"])
        end

        if @schedule.complete!(payment)
          render_success(serialize_schedule(@schedule))
        else
          render_errors(@schedule.errors.full_messages)
        end
      end

      # ── POST /api/v1/collection_schedules/:id/skip ────────────────────────
      def skip
        authorize @schedule, :skip?

        reason = params[:reason].to_s.strip
        return render_errors(["Reason is required to skip a schedule"]) if reason.blank?

        if @schedule.skip!(reason)
          render_success(serialize_schedule(@schedule))
        else
          render_errors(@schedule.errors.full_messages)
        end
      end

      # ── POST /api/v1/collection_schedules/:id/reschedule ─────────────────
      def reschedule
        authorize @schedule, :reschedule?

        new_date = Date.parse(params[:scheduled_date].to_s) rescue nil
        return render_errors(["scheduled_date is required"]) unless new_date

        # Create a new planned schedule for the rescheduled date
        new_schedule = CollectionSchedule.create!(
          organization:    @schedule.organization,
          branch:          @schedule.branch,
          customer:        @schedule.customer,
          assigned_to:     @schedule.assigned_to,
          scheduled_date:  new_date,
          amount_expected: @schedule.amount_expected,
          notes:           @schedule.notes,
          status:          "planned"
        )

        @schedule.reschedule!(new_date)

        render_success({
          original:        serialize_schedule(@schedule),
          rescheduled_to:  serialize_schedule(new_schedule)
        })
      end

      private

      def set_schedule
        @schedule = policy_scope(CollectionSchedule)
                      .includes(SCHEDULE_INCLUDES)
                      .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Collection schedule")
      end

      def schedule_params
        params.permit(
          :branch_id, :customer_id, :assigned_to_id,
          :scheduled_date, :amount_expected, :notes
        )
      end

      def apply_filters(scope)
        scope = scope.for_branch(params[:branch_id])       if params[:branch_id].present?
        scope = scope.for_user(params[:assigned_to_id])    if params[:assigned_to_id].present?
        scope = scope.for_customer(params[:customer_id])   if params[:customer_id].present?
        scope = scope.where(status: params[:status])       if params[:status].present?
        if params[:date_from].present? && params[:date_to].present?
          scope = scope.for_date_range(params[:date_from], params[:date_to])
        elsif params[:date_from].present?
          scope = scope.where("scheduled_date >= ?", params[:date_from])
        elsif params[:date_to].present?
          scope = scope.where("scheduled_date <= ?", params[:date_to])
        elsif params[:date].present?
          scope = scope.for_date(params[:date])
        end
        scope
      end

      def serialize_schedule(s)
        {
          id:               s.id,
          scheduled_date:   s.scheduled_date,
          amount_expected:  s.amount_expected.to_f,
          status:           s.status,
          notes:            s.notes,
          skip_reason:      s.skip_reason,
          rescheduled_to:   s.rescheduled_to,
          created_at:       s.created_at,
          updated_at:       s.updated_at,
          customer: {
            id:             s.customer.id,
            name:           s.customer.name,
            code:           s.customer.code
          },
          branch: {
            id:             s.branch.id,
            name:           s.branch.name,
            code:           s.branch.code
          },
          assigned_to: {
            id:             s.assigned_to.id,
            name:           s.assigned_to.full_name
          },
          completed_payment: s.completed_payment_id ? {
            id:             s.completed_payment.id,
            payment_number: s.completed_payment.payment_number,
            amount:         s.completed_payment.amount.to_f
          } : nil
        }
      end
    end
  end
end
