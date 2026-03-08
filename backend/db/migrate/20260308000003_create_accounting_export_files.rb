# Stores metadata for generated export file batches (e.g. Tally XML exports).
# file_path retained for direct filesystem/S3 path even if ActiveStorage is added later.
#
# BRANCH FK DECISION:
#   branches table EXISTS in this app — foreign key is included.
#   If you ever need to run this migration in an environment without branches,
#   remove the add_foreign_key line for branch_id (the nullable column is safe either way).
class CreateAccountingExportFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_export_files do |t|
      # Tenant scoping
      t.references :organization, null: false, foreign_key: true

      t.references :accounting_integration, null: false, foreign_key: true

      # Denormalized for direct queries without joining accounting_integrations
      t.string :provider, null: false

      # What entity set this export covers
      # "all" | "invoices" | "payments" | "credit_notes" | "purchase_invoices" | "masters"
      t.string :export_type, null: false

      # Optional date range filter applied when generating the export
      t.date :date_from
      t.date :date_to

      # Optional branch-scoped export (branches table exists — FK added below)
      t.references :branch, null: true, foreign_key: true

      # Arbitrary user-supplied filters captured at generation time (for audit/replay)
      t.jsonb :filters_json, null: false, default: {}

      # Storage path for the generated file; kept alongside ActiveStorage for direct URLs
      t.string :file_path

      # Generation lifecycle
      # "generating" | "ready" | "failed"
      t.string :status, null: false, default: "generating"

      # Who requested the export
      t.references :generated_by, null: true, foreign_key: { to_table: :users }

      t.text :error_message

      t.timestamps
    end

    # Primary listing query: "show all exports for this org/provider"
    add_index :accounting_export_files, [:organization_id, :provider],
              name: "idx_accounting_export_files_org_provider"

    # Status polling: front-end polls until status == "ready"
    add_index :accounting_export_files, [:organization_id, :status],
              name: "idx_accounting_export_files_org_status"

    add_index :accounting_export_files, :accounting_integration_id,
              name: "idx_accounting_export_files_integration"

    # Filter by export type in reporting/admin views
    add_index :accounting_export_files, :export_type,
              name: "idx_accounting_export_files_export_type"

    # Default sort order for listing pages
    add_index :accounting_export_files, :created_at,
              name: "idx_accounting_export_files_created_at"
  end
end
