class CreateSalesInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_invoices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :customer,     null: false, foreign_key: true
      t.references :sales_order,  null: true,  foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      t.string  :invoice_number, null: false
      t.date    :invoice_date,   null: false
      t.date    :due_date
      t.string  :status,         null: false, default: 'draft'

      # Financial totals (frozen at generation)
      t.decimal :subtotal,    precision: 14, scale: 2, null: false, default: '0.00'
      t.decimal :tax_total,   precision: 14, scale: 2, null: false, default: '0.00'
      t.decimal :grand_total, precision: 14, scale: 2, null: false, default: '0.00'
      t.decimal :round_off,   precision: 8,  scale: 2, default: '0.00'

      t.string  :currency, null: false, default: 'INR'
      t.text    :notes

      # Lifecycle timestamps
      t.datetime :issued_at
      t.datetime :voided_at
      t.text     :void_reason

      # PDF storage key (ActiveStorage attachment stored separately)
      t.string   :pdf_key
      t.datetime :pdf_generated_at

      # Soft-delete
      t.datetime :deleted_at

      # Provenance
      t.string :generation_source, default: 'manual_direct'
      t.jsonb  :metadata, default: {}, null: false

      t.timestamps null: false
    end

    add_index :sales_invoices, [:organization_id, :invoice_number],
              unique: true,
              name: 'idx_sales_invoices_org_number'
    add_index :sales_invoices, [:organization_id, :status],
              name: 'idx_sales_invoices_org_status'
    add_index :sales_invoices, [:customer_id, :status],
              name: 'idx_sales_invoices_customer_status'
    add_index :sales_invoices, :deleted_at
    add_index :sales_invoices, :invoice_date
    add_index :sales_invoices, :metadata, using: :gin
  end
end
