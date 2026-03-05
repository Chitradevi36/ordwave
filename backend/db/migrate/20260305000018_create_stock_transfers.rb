class CreateStockTransfers < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_transfers do |t|
      t.references :organization,       null: false, foreign_key: true
      t.references :source_branch,      null: false, foreign_key: { to_table: :branches }
      t.references :destination_branch, null: false, foreign_key: { to_table: :branches }
      t.string  :transfer_number, null: false
      t.date    :transfer_date,   null: false
      t.string  :status,          null: false, default: 'draft'
      t.text    :notes
      t.references :created_by,    null: false, foreign_key: { to_table: :users }
      t.references :dispatched_by, null: true,  foreign_key: { to_table: :users }
      t.datetime   :dispatched_at
      t.references :received_by,   null: true,  foreign_key: { to_table: :users }
      t.datetime   :received_at
      t.text    :cancellation_reason
      t.jsonb   :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :stock_transfers, [:organization_id, :transfer_number], unique: true
    add_index :stock_transfers, [:source_branch_id, :status]
    add_index :stock_transfers, [:destination_branch_id, :status]
    add_index :stock_transfers, :status
  end
end
