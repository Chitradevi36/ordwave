# frozen_string_literal: true

module Accounting
  # Generates a Tally XML batch export file for an AccountingExportFile record.
  #
  # Enqueued when an AccountingExportFile is created with status "pending".
  # The job delegates entirely to GenerateBatchExportService.
  class GenerateBatchExportJob < ApplicationJob
    queue_as :accounting

    discard_on ActiveJob::DeserializationError

    # @param accounting_export_file_id [Integer]
    def perform(accounting_export_file_id)
      export_file = AccountingExportFile.find_by(id: accounting_export_file_id)

      unless export_file
        Rails.logger.warn(
          "[GenerateBatchExportJob] AccountingExportFile##{accounting_export_file_id} not found — discarding"
        )
        return
      end

      Accounting::Sync::GenerateBatchExportService.new(export_file).call
    end
  end
end
