# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/audit_logs
    # Returns a paginated, filterable list of audit log entries for the
    # current organization. Restricted to owners, admins, and managers.
    class AuditLogsController < BaseController
      before_action :require_organization!

      def index
        authorize :audit_log, :index?

        scope = AuditLog
          .includes(:actor)
          .where(organization: current_organization)
          .order(created_at: :desc)

        scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
        scope = scope.where(actor_id: params[:actor_id])             if params[:actor_id].present?
        scope = scope.where(action: params[:action])                 if params[:action].present?

        if params[:date_from].present?
          scope = scope.where('audit_logs.created_at >= ?', params[:date_from].to_date.beginning_of_day)
        end
        if params[:date_to].present?
          scope = scope.where('audit_logs.created_at <= ?', params[:date_to].to_date.end_of_day)
        end

        logs = paginate(scope)

        render_success(
          logs.map { |l| serialize_log(l) },
          meta: pagination_meta(logs)
        )
      end

      private

      def serialize_log(log)
        {
          id:             log.id,
          action:         log.action,
          auditable_type: log.auditable_type,
          auditable_id:   log.auditable_id,
          reason:         log.reason,
          changes:        log.changes_data,
          created_at:     log.created_at.iso8601,
          actor: {
            id:   log.actor_id,
            name: log.actor&.full_name
          }
        }
      end
    end
  end
end
