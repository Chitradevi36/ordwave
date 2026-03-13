# frozen_string_literal: true

module Api
  module V1
    class BankStatementImportsController < BaseController
      before_action :set_import, only: %i[show]

      def index
        imports = policy_scope(BankStatementImport)
                    .order(created_at: :desc)
                    .page(params[:page])
                    .per(params[:per_page] || 20)

        render json: imports, each_serializer: BankStatementImportSerializer,
               meta: pagination_meta(imports)
      end

      def show
        authorize @import
        render json: @import, serializer: BankStatementImportSerializer
      end

      def create
        bank_account = policy_scope(BankAccount).find_by!(id: params[:bank_account_id])

        import = BankStatementImport.new(
          organization:  Current.organization,
          bank_account:  bank_account,
          source_type:   detect_source_type(csv_file.original_filename),
          uploaded_by:   Current.user,
          file_name:     csv_file.original_filename,
          status:        "uploaded"
        )
        import.csv_file.attach(csv_file)

        authorize import

        if import.save
          ProcessBankStatementImportJob.perform_later(import.id)
          render json: import, serializer: BankStatementImportSerializer, status: :accepted
        else
          render json: { errors: import.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_import
        @import = policy_scope(BankStatementImport).find(params[:id])
      end

      def csv_file
        params.require(:file)
      end

      def detect_source_type(filename)
        ext = File.extname(filename.to_s).downcase.delete(".")
        { "csv" => "csv", "xlsx" => "xlsx", "xls" => "xlsx", "pdf" => "pdf" }.fetch(ext, "csv")
      end
    end
  end
end
