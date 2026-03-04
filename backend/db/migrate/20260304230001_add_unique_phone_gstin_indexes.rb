class AddUniquePhoneGstinIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Partial unique index: phone is unique per org, but only for non-deleted rows
    add_index :customers, %i[organization_id phone],
              unique:    true,
              where:     "phone IS NOT NULL AND deleted_at IS NULL",
              algorithm: :concurrently,
              name:      "idx_customers_org_phone_unique"

    # Partial unique index: GSTIN is unique per org, but only for non-deleted rows
    add_index :customers, %i[organization_id gstin],
              unique:    true,
              where:     "gstin IS NOT NULL AND deleted_at IS NULL",
              algorithm: :concurrently,
              name:      "idx_customers_org_gstin_unique"
  end
end
