# frozen_string_literal: true

module Web
  module Accounting
    # Export Center — create and monitor batch XML export files for Tally.
    #
    # Screens:
    #   GET  /web/accounting/export_files           — index
    #   GET  /web/accounting/export_files/new       — new export form
    #   POST /web/accounting/export_files           — create + enqueue job
    #   GET  /web/accounting/export_files/:id       — show
    #   GET  /web/accounting/export_files/:id/download — send_file
    class ExportFilesController < Web::BaseController
      helper Web::AccountingHelper

      before_action :set_export_file, only: %i[show download]

      EXPORT_TYPES = %w[all invoices payments credit_notes purchase_invoices masters].freeze

      # GET /web/accounting/export_files
      def index
        authorize AccountingExportFile
        @export_files = policy_scope(AccountingExportFile)
                          .includes(:accounting_integration, :generated_by, :branch)
                          .order(created_at: :desc)
                          .page(params[:page]).per(20)
        @integrations = AccountingIntegration.where(organization: current_organization)
                                             .order(:provider)
      end

      # GET /web/accounting/export_files/new
      def new
        @export_file  = AccountingExportFile.new
        authorize @export_file
        @integrations = AccountingIntegration.where(organization: current_organization)
                                             .where(status: %w[connected error])
                                             .order(:provider)
        @branches     = Branch.where(organization: current_organization).order(:name) rescue []
        @export_types = EXPORT_TYPES
      end

      # POST /web/accounting/export_files
      def create
        @export_file = AccountingExportFile.new(export_file_params)
        @export_file.organization  = current_organization
        @export_file.generated_by  = current_user
        @export_file.status        = "generating"
        authorize @export_file

        if @export_file.save
          ::Accounting::GenerateBatchExportJob.perform_later(@export_file.id)
          redirect_to web_accounting_export_file_path(@export_file),
                      notice: "Export job enqueued. The file will be ready shortly."
        else
          @integrations = AccountingIntegration.where(organization: current_organization)
                                               .where(status: %w[connected error])
                                               .order(:provider)
          @branches     = Branch.where(organization: current_organization).order(:name) rescue []
          @export_types = EXPORT_TYPES
          render :new, status: :unprocessable_entity
        end
      end

      # GET /web/accounting/export_files/:id
      def show
        authorize @export_file
      end

      # GET /web/accounting/export_files/:id/download
      def download
        authorize @export_file

        unless @export_file.downloadable?
          return redirect_to web_accounting_export_file_path(@export_file),
                             alert: "Export file is not ready for download."
        end

        path = @export_file.file_path
        unless File.exist?(path)
          return redirect_to web_accounting_export_file_path(@export_file),
                             alert: "File not found on disk. It may have been moved or deleted."
        end

        send_file path,
                  filename: File.basename(path),
                  type:     "application/xml",
                  disposition: "attachment"
      end

      private

      def set_export_file
        @export_file = policy_scope(AccountingExportFile)
                         .includes(:accounting_integration, :generated_by, :branch)
                         .find(params[:id])
      end

      def export_file_params
        params.require(:accounting_export_file)
              .permit(:accounting_integration_id, :export_type,
                      :date_from, :date_to, :branch_id)
      end
    end
  end
end
