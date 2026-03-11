# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # GSTR-2B import and management.
      #
      # POST /api/v1/compliance/gstr2b/import   — Upload + import a GSTR-2B JSON
      # GET  /api/v1/compliance/gstr2b/imports  — List imports for period
      # GET  /api/v1/compliance/gstr2b/imports/:id — Import detail with reconciliation summary
      # GET  /api/v1/compliance/gstr2b/imports/:id/lines — Paginated import lines
      #
      class Gstr2bController < BaseController
        before_action :require_organization!
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/gstr2b/imports
        def imports
          imports = Gst2bImport.for_org(current_organization).recent

          imports = imports.where(month: params[:month].to_i)   if params[:month].present?
          imports = imports.where(year:  params[:year].to_i)    if params[:year].present?
          imports = imports.where(gstin: params[:gstin])        if params[:gstin].present?
          imports = imports.where(branch_id: params[:branch_id]) if params[:branch_id].present?

          render_success(imports.map { |imp| serialize_import(imp) })
        end

        # GET /api/v1/compliance/gstr2b/imports/:id
        def show_import
          @import = Gst2bImport.for_org(current_organization).find(params[:id])
          render_success(serialize_import(@import, detailed: true))
        rescue ActiveRecord::RecordNotFound
          render_not_found('Gst2bImport')
        end

        # GET /api/v1/compliance/gstr2b/imports/:id/lines
        def lines
          @import = Gst2bImport.for_org(current_organization).find(params[:id])
          lines   = @import.gst2b_import_lines

          lines = lines.where(match_status: params[:match_status]) if params[:match_status].present?
          lines = lines.where(supplier_gstin: params[:gstin])      if params[:gstin].present?
          lines = lines.order(created_at: :asc)
          lines = lines.page(params[:page]).per(params[:per_page] || 50)

          render_success({
            total:       lines.total_count,
            page:        lines.current_page,
            per_page:    lines.limit_value,
            lines:       lines.map { |l| serialize_line(l) }
          })
        rescue ActiveRecord::RecordNotFound
          render_not_found('Gst2bImport')
        end

        # POST /api/v1/compliance/gstr2b/import
        # Multipart or JSON body:
        #   gstin, month, year, file (JSON upload) OR json_payload (raw JSON)
        def import
          gstin   = params.require(:gstin)
          month   = params.require(:month).to_i
          year    = params.require(:year).to_i

          # Accept either multipart file upload or raw JSON param
          raw_payload = if params[:file].present?
                          content = params[:file].read
                          JSON.parse(content)
                        elsif params[:json_payload].present?
                          pp = params[:json_payload]
                          pp.is_a?(String) ? JSON.parse(pp) : pp.to_unsafe_h
                        else
                          return render_errors(['Either file upload or json_payload is required'],
                                               status: :unprocessable_entity)
                        end

          # Enqueue background job for large payloads; run inline for small ones
          result = Gst::Gstr2b::Importer.call(
            organization:  current_organization,
            branch:        current_branch,
            gstin:         gstin,
            month:         month,
            year:          year,
            raw_payload:   raw_payload,
            file_name:     params[:file]&.original_filename || "gstr2b_#{month}_#{year}.json",
            imported_by:   current_user
          )

          if result.success?
            render_success(serialize_import(result.import, detailed: true), status: :created)
          else
            render_errors(result.errors, status: :unprocessable_entity)
          end

        rescue JSON::ParserError => e
          render_errors(["Invalid JSON: #{e.message}"], status: :unprocessable_entity)
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        private

        def current_branch
          return nil unless params[:branch_id].present?
          Branch.find_by(id: params[:branch_id], organization_id: current_organization.id)
        end

        def serialize_import(imp, detailed: false)
          base = {
            id:            imp.id,
            gstin:         imp.gstin,
            month:         imp.month,
            year:          imp.year,
            period_label:  imp.period_label,
            file_name:     imp.file_name,
            import_status: imp.import_status,
            total_rows:    imp.total_rows,
            matched_rows:  imp.matched_rows,
            unmatched_rows: imp.unmatched_rows,
            match_rate:    imp.match_rate,
            imported_at:   imp.imported_at,
            error_message: imp.error_message,
            branch_id:     imp.branch_id
          }
          return base unless detailed
          base.merge(
            issues: imp.gst_reconciliation_issues.open.by_severity.limit(20).map { |i|
              { id: i.id, issue_type: i.issue_type, severity: i.severity,
                invoice_number: i.invoice_number, supplier_gstin: i.supplier_gstin,
                difference_amount: i.difference_amount }
            }
          )
        end

        def serialize_line(line)
          {
            id:               line.id,
            supplier_gstin:   line.supplier_gstin,
            supplier_name:    line.supplier_name,
            invoice_number:   line.invoice_number,
            invoice_date:     line.invoice_date,
            invoice_value:    line.invoice_value,
            taxable_value:    line.taxable_value,
            igst:             line.igst,
            cgst:             line.cgst,
            sgst:             line.sgst,
            cess:             line.cess,
            document_type:    line.document_type,
            section_type:     line.section_type,
            match_status:     line.match_status,
            match_confidence: line.match_confidence,
            match_explanation: line.match_explanation,
            matched_purchase_invoice_id: line.matched_purchase_invoice_id
          }
        end
      end
    end
  end
end
