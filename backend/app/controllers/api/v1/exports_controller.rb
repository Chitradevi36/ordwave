module Api
  module V1
    class ExportsController < BaseController
      before_action :require_organization!

      # GET /api/v1/exports
      def index
        exports = policy_scope(
          Export.for_org(current_organization).recent.limit(50)
        )
        authorize Export
        render_success(exports.map { |e| serialize(e) })
      end

      # POST /api/v1/exports
      # Request a new export. Returns immediately; actual file generated async.
      def create
        authorize Export

        export = Export.create!(
          organization: current_organization,
          requested_by: current_user,
          export_type:  export_params[:export_type],
          format:       export_params[:format] || "csv",
          filters:      export_params[:filters] || {}
        )

        ExportJob.perform_later(export.id)

        render_created(serialize(export))
      end

      # GET /api/v1/exports/:id
      # Poll for status and download URL
      def show
        export = Export.find_by!(id: params[:id], organization: current_organization)
        authorize export
        render_success(serialize(export, include_url: true))
      end

      private

      def export_params
        params.require(:export).permit(
          :export_type, :format,
          filters: [:status, :from_date, :to_date, :branch_id]
        )
      end

      def serialize(export, include_url: false)
        h = {
          id:          export.id,
          export_type: export.export_type,
          format:      export.format,
          status:      export.status,
          row_count:   export.row_count,
          filters:     export.filters,
          created_at:  export.created_at,
          completed_at: export.completed_at,
          error_message: export.error_message,
        }
        h[:download_url] = export.download_url if include_url && export.file.attached?
        h
      end
    end
  end
end
