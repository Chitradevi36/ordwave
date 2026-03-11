# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # GST Return Periods — tracks filing lifecycle for each monthly return.
      #
      # GET  /api/v1/compliance/gst_periods              — list periods (filterable)
      # GET  /api/v1/compliance/gst_periods/:id          — show single period + snapshots
      # POST /api/v1/compliance/gst_periods/:id/review   — mark as reviewed by CA
      # POST /api/v1/compliance/gst_periods/:id/lock     — lock a period (prevent edits)
      # POST /api/v1/compliance/gst_periods/:id/file     — mark as filed
      # POST /api/v1/compliance/gst_periods/:id/reopen   — reopen a locked/filed period
      #
      class GstPeriodsController < BaseController
        before_action :require_organization!
        before_action :set_period, except: :index
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/gst_periods
        def index
          periods = GstReturnPeriod.for_org(current_organization)

          periods = periods.where(return_type: params[:return_type]) if params[:return_type].present?
          periods = periods.where(month: params[:month].to_i)  if params[:month].present?
          periods = periods.where(year:  params[:year].to_i)   if params[:year].present?
          periods = periods.where(branch_id: params[:branch_id]) if params[:branch_id].present?
          periods = periods.where(financial_year_id: params[:financial_year_id]) if params[:financial_year_id].present?

          render_success(periods.recent.map { |p| serialize_period(p) })
        end

        # GET /api/v1/compliance/gst_periods/:id
        def show
          render_success(serialize_period(@period, detailed: true))
        end

        # POST /api/v1/compliance/gst_periods/:id/review
        # Marks the period as reviewed by CA / accountant before locking.
        def review
          if @period.locked_or_filed?
            return render_errors(['Period is already locked or filed and cannot be marked reviewed'],
                                 status: :unprocessable_entity)
          end
          unless @period.generated?
            return render_errors(["Period must be in 'generated' status to be reviewed (currently: #{@period.status})"],
                                 status: :unprocessable_entity)
          end
          @period.mark_reviewed!(by_user: current_user)
          render_success(serialize_period(@period))
        rescue RuntimeError => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # POST /api/v1/compliance/gst_periods/:id/lock
        def lock
          if @period.locked_or_filed?
            return render_errors(['Period is already locked or filed'], status: :unprocessable_entity)
          end
          @period.lock!(by_user: current_user)
          render_success(serialize_period(@period))
        rescue RuntimeError => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # POST /api/v1/compliance/gst_periods/:id/file
        def file
          unless @period.locked?
            return render_errors(['Period must be locked before filing'], status: :unprocessable_entity)
          end
          notes = params[:filing_notes]
          @period.file!(by_user: current_user, notes: notes)
          render_success(serialize_period(@period))
        rescue RuntimeError => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # POST /api/v1/compliance/gst_periods/:id/reopen
        def reopen
          unless @period.reopenable?
            return render_errors(['Period cannot be reopened in its current status'], status: :unprocessable_entity)
          end
          reason = params[:reason].presence || 'Reopened by user'
          @period.reopen!(by_user: current_user, reason: reason)
          render_success(serialize_period(@period))
        end

        private

        def set_period
          @period = GstReturnPeriod.for_org(current_organization).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_not_found('GstReturnPeriod')
        end

        def serialize_period(period, detailed: false)
          base = {
            id:                   period.id,
            return_type:          period.return_type,
            month:                period.month,
            year:                 period.year,
            display_name:         period.display_name,
            filing_period_code:   period.filing_period_code,
            status:               period.status,
            error_count:          period.error_count,
            warning_count:        period.warning_count,
            generated_at:         period.generated_at,
            reviewed_by_id:       period.reviewed_by_id,
            locked_at:            period.locked_at,
            filed_at:             period.filed_at,
            financial_year_id:    period.financial_year_id,
            financial_year_label: period.financial_year_label,
            branch_id:            period.branch_id
          }
          return base unless detailed
          base.merge(
            snapshots: period.gst_return_snapshots.latest_first.map { |s|
              {
                id:             s.id,
                section_key:    s.section_key,
                version_number: s.version_number,
                is_filed:       s.is_filed,
                generated_at:   s.generated_at,
                totals:         s.totals
              }
            }
          )
        end
      end
    end
  end
end
