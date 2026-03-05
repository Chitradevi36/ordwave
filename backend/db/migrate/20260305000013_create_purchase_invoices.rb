class CreatePurchaseInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :purchase_invoices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :supplier,     null: false, foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }
      t.string  :invoice_number,   null: false
      t.date    :invoice_date,     null: false
      t.date    :due_date
      t.string  :status,           null: false, default: 'draft'   # draft / posted / cancelled
      t.decimal :total_amount,     precision: 14, scale: 2, null: false, default: 0
      t.decimal :tax_amount,       precision: 14, scale: 2, null: false, default: 0
      t.decimal :grand_total,      precision: 14, scale: 2, null: false, default: 0
      t.string  :currency,         null: false, default: 'INR'
      t.text    :notes
      t.datetime :posted_at
      t.datetime :cancelled_at
      t.text    :cancellation_reason
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :purchase_invoices, :status
    add_index :purchase_invoices, :invoice_date
    add_index :purchase_invoices, :deleted_at
    add_index :purchase_invoices, %i[supplier_id invoice_number],
              unique: true,
              where:  'deleted_at IS NULL',
              name:   'index_purchase_invoices_supplier_number_unique'
  end
end
