# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # GST Reconciliation issues — view and resolve.
      #
      # GET  /api/v1/compliance/reconciliation/issues  — list issues (filterable)
      # GET  /api/v1/compliance/reconciliation/summary — severity + type summary for a period
      # POST /api/v1/compliance/reconciliation/run     — run engine for a period
      # POST /api/v1/compliance/reconciliation/issues/:id/resolve   — resolve issue
      # POST /api/v1/compliance/reconciliation/issues/:id/acknowledge — acknowledge
      # POST /api/v1/compliance/reconciliation/issues/:id/ignore    — ignore (with reason)
      #
      class ReconciliationController < BaseController
        before_action :require_organization!
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/reconciliation/issues
        def issues
          scope = GstReconciliationIssue.for_org(current_organization).by_severity.recent

          scope = scope.where(issue_type:         params[:issue_type])    if params[:issue_type].present?
          scope = scope.where(severity:           params[:severity])      if params[:severity].present?
          scope = scope.where(status:             params[:status])        if params[:status].present?
          scope = scope.where(supplier_gstin:     params[:gstin])         if params[:gstin].present?
          scope = scope.where(financial_year_id:  params[:financial_year_id]) if params[:financial_year_id].present?
          scope = scope.where(gst_return_period_id: params[:period_id])   if params[:period_id].present?

          scope = scope.page(params[:page]).per(params[:per_page] || 50)

          render_success({
            total:  scope.total_count,
            issues: scope.map { |i| serialize_issue(i) }
          })
        end

        # GET /api/v1/compliance/reconciliation/summary
        # Params: month, year (required)
        def summary
          month = params.require(:month).to_i
          year  = params.require(:year).to_i

          base_scope = GstReconciliationIssue.for_org(current_organization)
                         .where(
                           'EXTRACT(MONTH FROM created_at) = ? AND EXTRACT(YEAR FROM created_at) = ?',
                           month, year
                         )

          by_severity = base_scope.group(:severity).count
          by_type     = base_scope.group(:issue_type).count
          by_status   = base_scope.group(:status).count

          render_success({
            month:       month,
            year:        year,
            total:       base_scope.count,
            by_severity: by_severity,
            by_type:     by_type,
            by_status:   by_status,
            blocking_count: base_scope.blocking.unresolved.count
          })
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # POST /api/v1/compliance/reconciliation/run
        # Params: month, year
        def run
          month = params.require(:month).to_i
          year  = params.require(:year).to_i

          result = Gst::Reconciliation::Engine.call(
            organization: current_organization,
            month:        month,
            year:         year
          )

          if result.success?
            render_success({
              issue_count:        result.issue_count,
              issues_by_severity: result.issues_by_severity
            })
          else
            render_errors(result.errors, status: :unprocessable_entity)
          end
        rescue ActionController::ParameterMissing => e
          render_errors([e.message], status: :unprocessable_entity)
        end

        # POST /api/v1/compliance/reconciliation/issues/:id/resolve
        def resolve
          issue = find_issue!
          issue.resolve!(by_user: current_user, notes: params[:notes])
          render_success(serialize_issue(issue))
        end

        # POST /api/v1/compliance/reconciliation/issues/:id/acknowledge
        def acknowledge
          issue = find_issue!
          issue.acknowledge!(by_user: current_user)
          render_success(serialize_issue(issue))
        end

        # POST /api/v1/compliance/reconciliation/issues/:id/ignore
        def ignore
          issue = find_issue!
          issue.ignore!(by_user: current_user, reason: params[:reason])
          render_success(serialize_issue(issue))
        end

        private

        def find_issue!
          GstReconciliationIssue.for_org(current_organization).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_not_found('GstReconciliationIssue') and return nil
        end

        def serialize_issue(issue)
          {
            id:              issue.id,
            issue_type:      issue.issue_type,
            severity:        issue.severity,
            status:          issue.status,
            summary:         issue.summary,
            supplier_gstin:  issue.supplier_gstin,
            customer_gstin:  issue.customer_gstin,
            invoice_number:  issue.invoice_number,
            invoice_date:    issue.invoice_date,
            amount_books:    issue.amount_books,
            amount_portal:   issue.amount_portal,
            difference_amount: issue.difference_amount,
            difference_formatted: issue.difference_formatted,
            resolution_notes: issue.resolution_notes,
            resolved_at:     issue.resolved_at,
            created_at:      issue.created_at
          }
        end
      end
    end
  end
end
