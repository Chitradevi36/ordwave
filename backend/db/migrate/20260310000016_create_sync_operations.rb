class CreateSyncOperations < ActiveRecord::Migration[7.1]
  def change
    create_table :sync_operations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true

      t.string  :idempotency_key, null: false
      t.string  :entity_type,     null: false   # 'order', 'payment', 'visit'
      t.string  :operation,       null: false    # 'create', 'update'
      t.jsonb   :payload,         null: false, default: {}
      t.string  :status,          null: false, default: 'pending'  # pending, success, conflict, error
      t.integer :server_id
      t.text    :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :sync_operations, :idempotency_key, unique: true
    add_index :sync_operations, [:organization_id, :status]
    add_index :sync_operations, [:organization_id, :entity_type]
  end
end
