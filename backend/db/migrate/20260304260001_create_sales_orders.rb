class CreateSalesOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_orders do |t|
      t.references :organization,  null: false, foreign_key: true
      t.references :branch,        null: false, foreign_key: true
      t.references :customer,      null: false, foreign_key: true
      t.references :created_by,    null: false, foreign_key: { to_table: :users }

      t.string  :order_number,          null: false
      t.string  :status,                null: false, default: 'draft'
      t.date    :delivery_date
      t.text    :notes
      t.string  :idempotency_key

      # Credit engine snapshot (frozen at submit)
      t.string  :credit_decision
      t.jsonb   :credit_snapshot,       default: {}
      t.jsonb   :credit_reasons,        default: []

      # Financials (frozen at submit)
      t.decimal :total_amount,          precision: 14, scale: 2, default: 0
      t.decimal :discount_amount,       precision: 14, scale: 2, default: 0

      # Transition timestamps
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :cancelled_at
      t.text     :cancellation_reason

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :sales_orders, :order_number
    add_index :sales_orders, [:organization_id, :order_number], unique: true
    add_index :sales_orders, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
    add_index :sales_orders, :status
    add_index :sales_orders, :deleted_at
  end
end
