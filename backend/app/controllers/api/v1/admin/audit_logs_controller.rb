module Api
  module V1
    module Admin
      class AuditLogsController < BaseController
        before_action :require_admin!

        def index
          scope = AdminAuditLog.for_org(current_organization).recent

          # Filters
          scope = scope.by_action(params[:action_type]) if params[:action_type].present?
          scope = scope.by_resource(params[:resource_type]) if params[:resource_type].present?
          scope = scope.by_admin(params[:admin_user_id]) if params[:admin_user_id].present?

          if params[:start_date].present? && params[:end_date].present?
            scope = scope.by_date_range(
              Date.parse(params[:start_date]),
              Date.parse(params[:end_date])
            )
          end

          # Pagination
          audit_logs = paginate(scope)

          render_success(
            audit_logs.map { |log| serialize_audit_log(log) },
            meta: pagination_meta(audit_logs)
          )
        end

        def show
          audit_log = AdminAuditLog.find(params[:id])
          authorize audit_log, :show?

          render_success(serialize_audit_log(audit_log, detailed: true))
        end

        private

        def serialize_audit_log(log, detailed: false)
          {
            id: log.id,
            action_type: log.action_type,
            resource_type: log.resource_type,
            resource_name: log.resource_name,
            admin_user: {
              id: log.admin_user.id,
              email: log.admin_user.email,
              name: log.admin_user.name
            },
            changes: log.changes,
            before_values: detailed ? log.before_values : nil,
            after_values: detailed ? log.after_values : nil,
            reason: log.reason,
            ip_address: detailed ? log.ip_address : nil,
            created_at: log.created_at,
            status: log.status
          }.compact
        end
      end
    end
  end
end
