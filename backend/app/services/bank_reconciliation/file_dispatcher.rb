# frozen_string_literal: true

module BankReconciliation
  # Routes a BankStatementImport to the correct parser based on source_type.
  # Called by ProcessBankStatementImportJob.
  #
  # Usage:
  #   result = BankReconciliation::FileDispatcher.new(
  #     import:    bank_statement_import,
  #     blob_path: "/path/to/uploaded/file"
  #   ).call
  #   result.success?   # => true
  #   result.summary    # => { total:, new:, duplicates:, failed: }
  class FileDispatcher
    SUPPORTED_TYPES = %w[csv xlsx pdf].freeze

    Result = Struct.new(:success, :summary, :errors, keyword_init: true) do
      def success? = success
    end

    def initialize(import:, blob_path:)
      @import    = import
      @blob_path = blob_path
    end

    def call
      unless SUPPORTED_TYPES.include?(@import.source_type)
        return failure("Unsupported source_type: #{@import.source_type.inspect}")
      end

      unless File.exist?(@blob_path.to_s)
        return failure("Uploaded file not found on storage: #{@blob_path}")
      end

      case @import.source_type
      when "csv"
        csv_data = File.read(@blob_path, encoding: "bom|utf-8")
        BankReconciliation::CsvImportService.call(
          import:   @import,
          csv_data: csv_data
        )
      when "xlsx"
        BankReconciliation::XlsxImportService.call(
          import:    @import,
          blob_path: @blob_path
        )
      when "pdf"
        BankReconciliation::PdfImportService.call(
          import:    @import,
          blob_path: @blob_path
        )
      end
    rescue StandardError => e
      Rails.logger.error("[FileDispatcher] import=#{@import.id} type=#{@import.source_type} error=#{e.message}")
      failure(e.message)
    end

    private

    def failure(msg)
      @import.mark_failed!(msg) rescue nil
      Result.new(success: false, summary: {}, errors: [msg])
    end
  end
end
