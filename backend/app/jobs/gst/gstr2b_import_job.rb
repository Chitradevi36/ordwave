# frozen_string_literal: true

module Gst
  # Background job for processing large GSTR-2B JSON imports asynchronously.
  #
  # Enqueued by Gstr2bController#import when the payload is too large to process
  # inline (>= INLINE_THRESHOLD rows).
  #
  # Usage:
  #   Gst::Gstr2bImportJob.perform_later(
  #     import_id: import.id
  #   )
  #
  class Gstr2bImportJob < ApplicationJob
    queue_as :gst_imports

    # Retry with exponential backoff; do not retry after parse-level failures.
    retry_on StandardError, wait: :exponentially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(import_id:)
      import = Gst2bImport.find(import_id)

      # Guard: already processed
      if import.completed? || import.failed?
        Rails.logger.info("[Gstr2bImportJob] Import #{import_id} already in status '#{import.import_status}' — skipping")
        return
      end

      Rails.logger.info("[Gstr2bImportJob] Starting matching for Import #{import_id}")

      Gst::Gstr2b::MatchingEngine.new(
        gst2b_import:  import,
        organization:  import.organization
      ).run!

      Rails.logger.info("[Gstr2bImportJob] Completed Import #{import_id}: " \
                        "#{import.total_rows} rows, #{import.matched_rows} matched")
    end
  end
end
