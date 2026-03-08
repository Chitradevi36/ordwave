# Editable per-integration ledger/group name mappings for each accounting provider.
# Rows are upserted by service code; unique constraint on (integration, key) prevents duplicates.
class CreateAccountingMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_mappings do |t|
      # Tenant scoping (also needed for org-level queries without joining integrations)
      t.references :organization, null: false, foreign_key: true

      t.references :accounting_integration, null: false, foreign_key: true

      # The logical mapping slot being configured.
      # Examples: "sales_ledger", "cgst_output_ledger", "retailers_group",
      #           "round_off_ledger", "igst_input_ledger", "suppliers_group"
      t.string :mapping_key, null: false

      # The provider-side name/value for this mapping key (e.g. "Sales Account @12%")
      t.string :mapping_value, null: false

      t.timestamps
    end

    # Ensures only one value per key per integration — enforced at DB level
    # Service layer uses upsert on this constraint
    add_index :accounting_mappings, [:accounting_integration_id, :mapping_key],
              unique: true,
              name: "idx_accounting_mappings_integration_key_unique"

    # "Fetch all CGST-related mappings for this org" style queries
    add_index :accounting_mappings, [:organization_id, :mapping_key],
              name: "idx_accounting_mappings_org_key"
  end
end
