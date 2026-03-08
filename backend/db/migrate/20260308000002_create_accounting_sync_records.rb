# High-volume append table tracking every outbound sync/export event.
# Drives retry queues, deduplication (idempotency_key), and audit dashboards.
class CreateAccountingSyncRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_sync_records do |t|
      # Tenant scoping — used in every dashboard query
      t.references :organization, null: false, foreign_key: true

      # Which integration configuration this record belongs to
      t.references :accounting_integration, null: false, foreign_key: true

      # Polymorphic-style entity reference (no FK — entity may be across tables)
      # e.g. "Invoice", "Payment", "CreditNote", "Retailer", "Product"
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false

      # Version string of the entity at time of sync (updated_at digest, lock_version, etc.)
      # Allows detecting if a re-sync is for an already-processed version
      t.string :entity_version, null: false

      # What triggered this record
      # e.g. "invoice_posted", "payment_recorded", "master_sync", "export_generated"
      t.string :event_type, null: false

      # Denormalized for worker queries that don't join to accounting_integrations
      t.string :provider, null: false

      # "outbound" only for now; reserved for future inbound reconciliation flows
      t.string :direction, null: false, default: "outbound"

      # Processing lifecycle
      # "pending" | "processing" | "success" | "failed" | "retrying" | "skipped"
      t.string :status, null: false, default: "pending"

      # Controls job queue priority
      # "high" | "medium" | "low"
      t.string :priority, null: false, default: "medium"

      # Deterministic key to prevent duplicate sync submissions (enforced unique at DB level)
      t.string :idempotency_key, null: false

      # Provider-assigned reference (e.g. Tally voucher number, Zoho Books invoice ID)
      t.string :external_reference

      # Full entity snapshot sent to the provider
      t.jsonb :payload_json, null: false, default: {}

      # Raw provider response body for debugging
      t.text :response_body

      # Last error message for display in dashboard and for retry logic
      t.text :error_message

      # Retry tracking
      t.integer :attempt_count, null: false, default: 0
      t.datetime :last_attempted_at
      t.datetime :succeeded_at

      t.timestamps
    end

    # Primary deduplication guard — prevents re-enqueueing the same logical sync
    add_index :accounting_sync_records, [:provider, :idempotency_key],
              unique: true,
              name: "idx_accounting_sync_records_idempotency_unique"

    # Dashboard: filter by org + status (most common query pattern)
    add_index :accounting_sync_records, [:organization_id, :status],
              name: "idx_accounting_sync_records_org_status"

    add_index :accounting_sync_records, [:organization_id, :provider],
              name: "idx_accounting_sync_records_org_provider"

    # Entity audit trail: "show all sync history for Invoice #42"
    add_index :accounting_sync_records, [:entity_type, :entity_id],
              name: "idx_accounting_sync_records_entity"

    # Integration-level queue management
    add_index :accounting_sync_records, [:accounting_integration_id, :status],
              name: "idx_accounting_sync_records_integration_status"

    # Pagination-friendly ordering on large tables
    add_index :accounting_sync_records, :created_at,
              name: "idx_accounting_sync_records_created_at"

    add_index :accounting_sync_records, :event_type,
              name: "idx_accounting_sync_records_event_type"

    add_index :accounting_sync_records, :priority,
              name: "idx_accounting_sync_records_priority"

    # Used by retry workers: find records stuck in processing/retrying
    add_index :accounting_sync_records, :last_attempted_at,
              name: "idx_accounting_sync_records_last_attempted_at"

    # Composite index for worker polling:
    # SELECT ... WHERE status IN ('pending','retrying') ORDER BY priority, created_at
    add_index :accounting_sync_records, [:status, :priority, :created_at],
              name: "idx_accounting_sync_records_worker_poll"
  end
end
