module Accounting
  # Processes event-triggered sync records automatically.
  # Runs every 15 minutes to batch and process pending sync records
  # created by order approvals, deliveries, and payment confirmations.
  #
  # Architecture:
  # 1. Find all pending sync records from last hour (within sync_schedule batch window)
  # 2. Group by organization to batch exports
  # 3. For each org, merge data_types array (union) and create single AccountingExportFile
  # 4. Enqueue GenerateBatchExportJob to generate XML
  # 5. Mark sync records as processing
  #
  # Idempotency: Uses export_file_id to prevent duplicate processing
  #
  class AutoSyncTriggeredRecordsJob
    include Sidekiq::Worker
    sidekiq_options queue: 'accounting', retry: 3

    def perform
      # Find pending event-triggered sync records from last hour
      # (to align with scheduling batch window - can be adjusted)
      pending_records = AccountingSyncRecord
        .where(status: 'pending')
        .where(trigger_type: %w[order_approved order_delivered payment_confirmed collection])
        .where('created_at >= ?', 1.hour.ago)
        .includes(:organization, :accounting_integration)

      return if pending_records.empty?

      # Group by organization to create per-org batch exports
      pending_records.group_by(&:organization_id).each do |org_id, records|
        process_org_batch(org_id, records)
      end
    rescue StandardError => e
      Rails.logger.error("[AutoSyncTriggeredRecordsJob] Failed: #{e.message}")
      raise
    end

    private

    def process_org_batch(org_id, records)
      organization = Organization.find(org_id)
      integration = organization.primary_accounting_integration
      
      return unless integration

      # Merge all data types from pending records (union)
      all_data_types = records
        .map { |r| r.data_types_array }
        .flatten
        .uniq
      
      # Create single batch export for this org with merged data types
      export_file = create_batch_export(organization, integration, all_data_types, records)
      return unless export_file

      # Update sync records with export reference
      records.update_all(
        export_file_id: export_file.id,
        status: 'processing',
        updated_at: Time.current
      )

      # Enqueue async job to generate XML export
      GenerateBatchExportJob.perform_later(export_file.id)

      Rails.logger.info(
        "[AutoSyncTriggeredRecordsJob] Batched #{records.count} sync records " \
        "for org #{organization.slug} into export #{export_file.id}"
      )
    end

    def create_batch_export(organization, integration, data_types, records)
      batch_size = organization.settings&.dig('sync_batch_size')&.to_i || 100

      export_file = AccountingExportFile.create!(
        organization_id: organization.id,
        integration_id: integration.id,
        export_type: 'batch',
        status: 'pending',
        data_types: data_types,
        batch_size: batch_size,
        source_sync_records: records,  # Track which sync records triggered this export
        metadata: {
          triggered_by: 'auto_sync_triggered_records_job',
          triggered_at: Time.current.iso8601,
          trigger_types: records.map(&:trigger_type).uniq,
          source_count: records.count
        }
      )

      export_file
    rescue StandardError => e
      Rails.logger.error(
        "[AutoSyncTriggeredRecordsJob] Failed to create batch export for org #{organization.id}: #{e.message}"
      )
      nil
    end
  end
end
