# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # Handles GSTR-1 preview and JSON export for GST compliance.
      #
      # GET  /api/v1/compliance/gstr1/preview  — Returns structured GSTR-1 data as JSON.
      # GET  /api/v1/compliance/gstr1/export   — Downloads the official GSTR-1 JSON file.
      #
      # Query params:
      #   period_from  YYYY-MM-DD  (defaults to start of current month)
      #   period_to    YYYY-MM-DD  (defaults to end of current month)
      #   branch_id    optional    (filter to a single branch)
      class Gstr1Controller < BaseController
        before_action :require_organization!
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/gstr1/preview
        def preview
          authorize :gstr1, :preview?

          result = Gst::Gstr1ExportService.call(
            organization: current_organization,
            period_from:  period_from,
            period_to:    period_to,
            branch_id:    params[:branch_id].presence
          )

          render_success(
            {
              period:             result.period,
              gstin:              result.gstin,
              b2b_invoices:       result.b2b_invoices,
              b2c_large:          result.b2c_large,
              b2c_small:          result.b2c_small,
              credit_debit_notes: result.credit_debit_notes,
              hsn_summary:        result.hsn_summary,
              document_summary:   result.document_summary
            }
          )
        end

        # GET /api/v1/compliance/gstr1/export
        # Downloads the GSTR-1 return as a JSON file ready for GST portal upload.
        def export
          authorize :gstr1, :export?

          result = Gst::Gstr1ExportService.call(
            organization: current_organization,
            period_from:  period_from,
            period_to:    period_to,
            branch_id:    params[:branch_id].presence
          )

          # Build the official GSTR-1 JSON envelope used by the GST portal.
          gstr1_json = {
            gstin:   result.gstin,
            fp:      period_from.strftime('%m%Y'),  # MMYYYY format required by portal
            gt:      nil,                            # Grand Total — populated by portal
            cur_gt:  nil,
            b2b:     result.b2b_invoices,
            b2cl:    result.b2c_large,
            b2cs:    result.b2c_small,
            cdnr:    result.credit_debit_notes,
            hsn:     { data: result.hsn_summary },
            doc_issue: result.document_summary
          }

          filename = "GSTR1_#{current_organization.gst_number}_#{period_from.strftime('%m%Y')}.json"

          send_data JSON.pretty_generate(gstr1_json),
                    type:        'application/json',
                    disposition: "attachment; filename=\"#{filename}\""
        end

        private

        def period_from
          @period_from ||= begin
            if params[:period_from].present?
              Date.parse(params[:period_from])
            elsif params[:month].present? && params[:year].present?
              Date.new(params[:year].to_i, params[:month].to_i, 1)
            else
              Date.current.beginning_of_month
            end
          end
        end

        def period_to
          @period_to ||= begin
            if params[:period_to].present?
              Date.parse(params[:period_to])
            elsif params[:month].present? && params[:year].present?
              Date.new(params[:year].to_i, params[:month].to_i, 1).end_of_month
            else
              Date.current.end_of_month
            end
          end
        end
      end
    end
  end
end
