class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :customer,     null: false, foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      t.string  :payment_number,   null: false
      t.decimal :amount,           null: false, precision: 14, scale: 2
      t.string  :payment_mode,     null: false, default: 'cash'
      t.string  :reference_number
      t.date    :received_date,    null: false
      t.string  :status,           null: false, default: 'draft'
      t.text    :notes
      t.decimal :allocated_amount, null: false, precision: 14, scale: 2, default: '0.0'
      t.decimal :unallocated_amount, null: false, precision: 14, scale: 2, default: '0.0'
      t.datetime :confirmed_at
      t.datetime :reversed_at
      t.text     :reversal_reason
      t.jsonb    :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payments, [:organization_id, :payment_number], unique: true,
              name: 'idx_payments_org_number'
    add_index :payments, [:organization_id, :status],
              name: 'idx_payments_org_status'
    add_index :payments, [:customer_id, :status],
              name: 'idx_payments_customer_status'
    add_index :payments, :received_date,
              name: 'idx_payments_received_date'
    add_index :payments, :payment_mode,
              name: 'idx_payments_mode'
    add_index :payments, :metadata, using: :gin,
              name: 'idx_payments_metadata'
  end
end
