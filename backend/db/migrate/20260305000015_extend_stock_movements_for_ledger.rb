class ExtendStockMovementsForLedger < ActiveRecord::Migration[7.1]
  def change
    # Add granular occurred_at, jsonb metadata, reference_line_id
    add_column :stock_movements, :occurred_at,       :datetime
    add_column :stock_movements, :metadata,          :jsonb,   default: {}, null: false
    add_column :stock_movements, :reference_line_id, :bigint   # optional line-level trace

    # Back-fill occurred_at from created_at for existing rows
    reversible do |dir|
      dir.up { execute "UPDATE stock_movements SET occurred_at = created_at WHERE occurred_at IS NULL" }
    end

    # Make occurred_at non-null after backfill
    change_column_null :stock_movements, :occurred_at, false

    # Composite index: primary ledger query pattern
    add_index :stock_movements,
              %i[organization_id branch_id product_id occurred_at],
              name: 'index_stock_movements_ledger'

    add_index :stock_movements, :reference_line_id,
              name: 'index_stock_movements_on_reference_line_id'
  end
end
