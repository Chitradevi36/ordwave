class CreateAdvancePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :advance_payments do |t|
      t.references :organization,    null: false, foreign_key: true
      t.references :branch,          null: false, foreign_key: true
      t.references :customer,        null: false, foreign_key: true
      # Link back to the source payment that generated this advance
      t.references :source_payment,  null: false, foreign_key: { to_table: :payments }

      t.decimal :original_amount,    null: false, precision: 14, scale: 2
      t.decimal :balance,            null: false, precision: 14, scale: 2
      t.string  :status,             null: false, default: 'unapplied'
        # unapplied | partially_applied | applied | refunded

      t.datetime :refunded_at
      t.text     :notes

      t.timestamps
    end

    add_index :advance_payments, [:organization_id, :customer_id, :status],
              name: 'idx_advance_payments_org_cust_status'
    add_index :advance_payments, :status,
              name: 'idx_advance_payments_status'
  end
end
