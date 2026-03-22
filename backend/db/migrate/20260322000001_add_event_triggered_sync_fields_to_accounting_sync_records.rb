# frozen_string_literal: true

class AddEventTriggeredSyncFieldsToAccountingSyncRecords < ActiveRecord::Migration[7.1]
  def change
    # Add event trigger fields
    add_column :accounting_sync_records, :trigger_type, :string, default: 'manual'
    add_column :accounting_sync_records, :source_type, :string, comment: 'Polymorphic type (e.g., SalesOrder, Payment)'
    add_column :accounting_sync_records, :source_id, :bigint, comment: 'Polymorphic ID'
    add_column :accounting_sync_records, :export_file_id, :bigint, comment: 'Associated AccountingExportFile'
    add_column :accounting_sync_records, :data_types, :jsonb, default: [], comment: 'Types of data to sync [invoices, payments, stock_movements]'

    # Add timestamps for tracking sync lifecycle
    add_column :accounting_sync_records, :synced_at, :datetime, comment: 'When sync completed successfully'
    add_column :accounting_sync_records, :failed_at, :datetime, comment: 'When sync failed'

    # Add indexes for common queries
    add_index :accounting_sync_records, [:organization_id, :status, :trigger_type]
    add_index :accounting_sync_records, [:trigger_type, :status], name: 'idx_sync_records_trigger_status'
    add_index :accounting_sync_records, [:source_type, :source_id]
    add_index :accounting_sync_records, [:export_file_id]
    add_index :accounting_sync_records, :trigger_type
  end
end
