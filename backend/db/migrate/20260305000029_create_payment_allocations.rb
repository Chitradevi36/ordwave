class CreatePaymentAllocations < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_allocations do |t|
      t.references :payment,       null: false, foreign_key: true
      t.references :sales_invoice, null: false, foreign_key: true
      t.decimal :allocated_amount, null: false, precision: 14, scale: 2
      t.string  :status,           null: false, default: 'active'
        # active | reversed
      t.datetime :reversed_at

      t.timestamps
    end

    add_index :payment_allocations, [:payment_id, :sales_invoice_id],
              name: 'idx_allocations_payment_invoice'
    add_index :payment_allocations, :sales_invoice_id,
              name: 'idx_allocations_invoice'
    add_index :payment_allocations, :status,
              name: 'idx_allocations_status'
  end
end
