# One row per organization per accounting provider.
# Stores connection config, sync mode, and last sync/error state.
class CreateAccountingIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_integrations do |t|
      # Core tenant scoping
      t.references :organization, null: false, foreign_key: true

      # Which accounting provider this integration is for
      # e.g. "tally", "zoho_books", "busy", "marg", "vyapar", "cleartax"
      t.string :provider, null: false

      # Lifecycle state — drives UI and sync eligibility
      # "disconnected" | "connected" | "error" | "disabled"
      t.string :status, null: false, default: "disconnected"

      # How sync is delivered for this integration
      # "batch_export" | "realtime_agent"
      t.string :sync_mode, null: false, default: "batch_export"

      # Provider-specific config (company name, port, paths, credentials, etc.)
      # Left intentionally schemaless for multi-provider flexibility
      t.jsonb :config_json, null: false, default: {}

      # Observability / health tracking
      t.datetime :last_synced_at
      t.datetime :last_error_at
      t.text :last_error_message

      # Audit: who connected this integration
      t.references :connected_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Enforce one integration per org per provider at the DB level
    add_index :accounting_integrations, [:organization_id, :provider],
              unique: true,
              name: "idx_accounting_integrations_org_provider_unique"

    # Used by dashboard status filters and sync eligibility checks
    add_index :accounting_integrations, :status,
              name: "idx_accounting_integrations_status"

    add_index :accounting_integrations, :sync_mode,
              name: "idx_accounting_integrations_sync_mode"

    # Used for "stale sync" queries: find integrations not synced in N hours
    add_index :accounting_integrations, :last_synced_at,
              name: "idx_accounting_integrations_last_synced_at"

    add_foreign_key :accounting_integrations, :users,
                    column: :connected_by_id,
                    name: "fk_accounting_integrations_connected_by"
  end
end
