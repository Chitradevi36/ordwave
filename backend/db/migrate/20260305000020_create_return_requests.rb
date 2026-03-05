class CreateReturnRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :return_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :customer,     null: false, foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      # Source linkage (delivery stop OR sales order OR manual)
      t.string  :source_type, null: false, default: 'manual'
      # source_type: delivery | order | manual
      t.bigint  :source_id   # trip_stop_id or sales_order_id (nullable)

      t.string  :return_number, null: false
      t.date    :return_date,   null: false
      t.string  :status,        null: false, default: 'draft'
      t.text    :notes
      t.text    :cancellation_reason

      # Timestamps for lifecycle events
      t.datetime :submitted_at
      t.datetime :qc_completed_at
      t.datetime :credit_note_issued_at
      t.datetime :cancelled_at

      # Soft delete
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :return_requests, %i[organization_id return_number], unique: true
    add_index :return_requests, %i[organization_id status]
    add_index :return_requests, %i[customer_id status]
    add_index :return_requests, %i[source_type source_id]
    add_index :return_requests, :deleted_at
  end
end
