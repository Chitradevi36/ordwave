# frozen_string_literal: true

module Api
  module V1
    # Manages FinancialYear records for the current organization.
    #
    # GET    /api/v1/financial_years              — list all FYs
    # GET    /api/v1/financial_years/:id          — show single FY
    # POST   /api/v1/financial_years              — create (auto-creates if not exists)
    # POST   /api/v1/financial_years/:id/lock_gst — lock GST for the year
    # POST   /api/v1/financial_years/:id/close    — close the year
    # GET    /api/v1/financial_years/:id/checklist— closing checklist
    #
    class FinancialYearsController < BaseController
      before_action :require_organization!
      before_action :set_financial_year, only: %i[show lock_gst close checklist]

      # GET /api/v1/financial_years
      def index
        policy_scope(FinancialYear)
        fys = FinancialYear.for_org(current_organization).recent
        render_success(fys.map { |fy| serialize_fy(fy) })
      end

      # GET /api/v1/financial_years/:id
      def show
        authorize @financial_year
        render_success(serialize_fy(@financial_year, detailed: true))
      end

      # POST /api/v1/financial_years
      # Body: { month: 9, year: 2025 }  OR  { start_date: '2025-04-01' }
      def create
        authorize FinancialYear
        resolver = Gst::Support::FinancialYearResolver.new(organization: current_organization)

        date = if params[:start_date].present?
                 Date.parse(params[:start_date])
               else
                 Date.new(params.require(:year).to_i, params.require(:month).to_i, 1)
               end

        fy = resolver.find_or_create_for_date!(date)
        render_success(serialize_fy(fy), status: :created)

      rescue ArgumentError, Date::Error => e
        render_errors([e.message], status: :unprocessable_entity)
      end

      # POST /api/v1/financial_years/:id/lock_gst
      def lock_gst
        authorize @financial_year, :lock?
        @financial_year.lock_gst!(by_user: current_user)
        render_success(serialize_fy(@financial_year))
      end

      # POST /api/v1/financial_years/:id/close
      def close
        authorize @financial_year, :close?
        checklist = @financial_year.closing_checklist
        unless checklist[:ready_to_close]
          return render_errors(
            ['Cannot close FY — checklist items are incomplete'],
            status: :unprocessable_entity,
            details: checklist[:checklist]
          )
        end
        @financial_year.close_year!(by_user: current_user)
        render_success(serialize_fy(@financial_year))
      end

      # GET /api/v1/financial_years/:id/checklist
      def checklist
        authorize @financial_year, :show?
        render_success(@financial_year.closing_checklist)
      end

      private

      def set_financial_year
        @financial_year = FinancialYear.for_org(current_organization).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found('FinancialYear')
      end

      def serialize_fy(fy, detailed: false)
        base = {
          id:              fy.id,
          code:            fy.code,
          label:           fy.label,
          start_date:      fy.start_date,
          end_date:        fy.end_date,
          status:          fy.status,
          gst_locked_at:   fy.gst_locked_at,
          books_locked_at: fy.books_locked_at,
          closed_at:       fy.closed_at,
          created_at:      fy.created_at
        }
        return base unless detailed
        base.merge(
          calendar_months: fy.calendar_months,
          return_periods:  fy.gst_return_periods.order(:year, :month).map { |p|
            { id: p.id, month: p.month, year: p.year,
              return_type: p.return_type, status: p.status }
          }
        )
      end
    end
  end
end
