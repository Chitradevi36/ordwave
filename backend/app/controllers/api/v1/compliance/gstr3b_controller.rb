# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # GSTR-3B computer and lifecycle management.
      #
      # POST /api/v1/compliance/gstr3b/generate — Compute 3B from books for a period
      # GET  /api/v1/compliance/gstr3b/show     — View latest 3B snapshot
      # GET  /api/v1/compliance/gstr3b/variance — Compare GSTR-1 vs GSTR-3B vs GSTR-2B
      #
      class Gstr3bController < BaseController
        before_action :require_organization!
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # POST /api/v1/compliance/gstr3b/generate
        # Params: month, year, branch_id (optional)
        def generate
          month  = params.require(:month).to_i
          year   = params.require(:year).to_i
          branch = params[:branch_id].present? ?
                   Branch.find_by(id: params[:branch_id], organization_id: current_organization.id) : nil

          result = Gst::Gstr3b::Builder.call(
            organization: current_organization,
            branch:       branch,
            month:        month,
            year:         year
          )

          if result.success?
            render_success({
              period:    serialize_period(result.period),
              snapshot:  serialize_snapshot(result.snapshot),
              payload:   result.payload
            }, status: :created)
          else
            render_errors(result.errors, status: :unprocessable_entity)
          end
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # GET /api/v1/compliance/gstr3b/show
        # Params: month, year, branch_id (optional)
        def show
          month  = params.require(:month).to_i
          year   = params.require(:year).to_i

          period = GstReturnPeriod.find_by(
            organization_id: current_organization.id,
            month: month, year: year, return_type: 'gstr3b'
          )

          unless period
            return render_errors(["No GSTR-3B period found for #{month}/#{year}. Please generate first."],
                                 status: :not_found)
          end

          snapshot = period.latest_snapshot
          render_success({
            period:   serialize_period(period),
            snapshot: snapshot ? serialize_snapshot(snapshot) : nil,
            payload:  snapshot&.payload
          })
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # GET /api/v1/compliance/gstr3b/variance
        #
        # Compares the latest GSTR-3B computation against the filed/latest
        # GSTR-1 export and the imported GSTR-2B for the same period.
        # The CA should resolve any flagged variances before filing.
        #
        # Params: month, year, branch_id (optional)
        #
        # Response shape:
        #   {
        #     status:       'complete' | 'partial' | 'missing_data',
        #     summary:      { period, gstr1_available, gstr3b_available, ... },
        #     gstr1_vs_3b:  { axis, cells: [{ key, label, source_value, target_value, difference, variance_flag }] },
        #     gstr2b_vs_3b: { axis, cells: [...], note },
        #     has_variances: true | false,
        #     errors:        []
        #   }
        def variance
          month  = params.require(:month).to_i
          year   = params.require(:year).to_i
          branch = params[:branch_id].present? ?
                   Branch.find_by(id: params[:branch_id], organization_id: current_organization.id) : nil

          result = Gst::Gstr3b::VarianceReporter.call(
            organization: current_organization,
            branch:       branch,
            month:        month,
            year:         year
          )

          render_success({
            status:        result.status,
            month:         result.month,
            year:          result.year,
            summary:       result.summary,
            gstr1_vs_3b:  result.gstr1_vs_3b,
            gstr2b_vs_3b: result.gstr2b_vs_3b,
            has_variances: result.has_variances?,
            errors:        result.errors
          })
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        private

        def serialize_period(period)
          {
            id:           period.id,
            month:        period.month,
            year:         period.year,
            status:       period.status,
            display_name: period.display_name
          }
        end

        def serialize_snapshot(snapshot)
          {
            id:             snapshot.id,
            version_number: snapshot.version_number,
            section_key:    snapshot.section_key,
            totals:         snapshot.totals,
            generated_at:   snapshot.generated_at,
            is_filed:       snapshot.is_filed
          }
        end
      end
    end
  end
end
