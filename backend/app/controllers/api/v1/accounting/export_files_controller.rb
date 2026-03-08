# frozen_string_literal: true

module Api
  module V1
    module Accounting
      class ExportFilesController < BaseController
        before_action :require_organization!
        before_action :set_export_file, only: %i[show download_url]

        # GET /api/v1/accounting/export_files
        def index
          scope  = policy_scope(AccountingExportFile).recent_first
          scope  = scope.where(status: params[:status]) if params[:status].present?
          scope  = scope.where(accounting_integration_id: params[:integration_id]) if params[:integration_id].present?
          files  = paginate(scope)

          render_success(
            files.map { |f| serialize(f) },
            meta: pagination_meta(files)
          )
        end

        # GET /api/v1/accounting/export_files/:id
        def show
          authorize @export_file
          render_success(serialize(@export_file, detailed: true))
        end

        # POST /api/v1/accounting/export_files
        def create
          integration = current_organization.accounting_integrations.find(export_params[:accounting_integration_id])
          export_file = current_organization.accounting_export_files.build(
            accounting_integration: integration,
            export_type:            export_params[:export_type],
            date_from:              export_params[:date_from],
            date_to:                export_params[:date_to],
            branch_id:              export_params[:branch_id],
            generated_by:           current_user,
            status:                 :generating
          )
          authorize export_file

          if export_file.save
            # Enqueue the background generation job
            ::Accounting::GenerateBatchExportJob.perform_later(export_file.id)
            render_created(serialize(export_file))
          else
            render_errors(export_file.errors.full_messages)
          end
        end

        # GET /api/v1/accounting/export_files/:id/download_url
        def download_url
          authorize @export_file

          unless @export_file.downloadable?
            return render json: { errors: ["File is not ready for download."] },
                          status: :unprocessable_entity
          end

          # In production this would generate a signed storage URL.
          # For now, return the stored file_path as a relative URL.
          url = if @export_file.file_path.start_with?("http")
                  @export_file.file_path
                else
                  request.base_url + @export_file.file_path
                end

          render_success({ url: url, expires_at: 15.minutes.from_now })
        end

        private

        def set_export_file
          @export_file = current_organization.accounting_export_files.find(params[:id])
        end

        def export_params
          params.require(:accounting_export_file).permit(
            :accounting_integration_id,
            :export_type,
            :date_from,
            :date_to,
            :branch_id
          )
        end

        def serialize(file, detailed: false)
          base = {
            id:           file.id,
            provider:     file.provider,
            export_type:  file.export_type,
            status:       file.status,
            date_from:    file.date_from,
            date_to:      file.date_to,
            file_path:    file.file_path,
            error_message: file.error_message,
            downloadable: file.downloadable?,
            accounting_integration: file.accounting_integration && {
              id:       file.accounting_integration.id,
              provider: file.accounting_integration.provider
            },
            generated_by: file.generated_by && {
              id:         file.generated_by.id,
              email:      file.generated_by.email,
              first_name: file.generated_by.first_name,
              last_name:  file.generated_by.last_name
            },
            branch: file.branch && {
              id:   file.branch.id,
              name: file.branch.name
            },
            created_at: file.created_at,
            updated_at: file.updated_at
          }
          base
        end
      end
    end
  end
end
