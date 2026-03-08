# frozen_string_literal: true

module Accounting
  # Processes a single AccountingSyncRecord through the provider adapter.
  #
  # Enqueued by:
  #   - Accounting::Sync::CreateSyncRecordService (initial processing)
  #   - Accounting::Sync::RetrySyncRecordService (re-enqueue on retry)
  #
  # The job itself is intentionally thin — all logic lives in
  # Accounting::Sync::ProcessSyncRecordService.
  class ProcessSyncRecordJob < ApplicationJob
    queue_as :accounting

    # Discard if the record has already been cleaned up.
    discard_on ActiveJob::DeserializationError

    # @param sync_record_id [Integer]
    def perform(sync_record_id)
      record = AccountingSyncRecord.find_by(id: sync_record_id)

      unless record
        Rails.logger.warn(
          "[ProcessSyncRecordJob] AccountingSyncRecord##{sync_record_id} not found — discarding"
        )
        return
      end

      Accounting::Sync::ProcessSyncRecordService.new(record).call
    end
  end
end
