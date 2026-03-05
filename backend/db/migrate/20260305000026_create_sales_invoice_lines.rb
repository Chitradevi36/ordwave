class CreateSalesInvoiceLines < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_invoice_lines do |t|
      t.references :sales_invoice, null: false, foreign_key: true
      t.references :product,       null: false, foreign_key: true

      # Quantity
      t.decimal :qty, precision: 14, scale: 3, null: false

      # Price snapshot (frozen at invoice creation — never recomputed from masters)
      t.decimal :unit_price,    precision: 14, scale: 2, null: false
      t.decimal :discount_pct,  precision: 5,  scale: 2, default: '0.00'
      t.decimal :taxable_value, precision: 14, scale: 2, null: false, default: '0.00'

      # HSN / GST snapshot
      t.string  :hsn_code
      t.decimal :gst_rate,   precision: 5,  scale: 2, null: false, default: '0.00'

      # Split tax snapshot
      t.decimal :cgst_rate,   precision: 5,  scale: 2, default: '0.00'
      t.decimal :sgst_rate,   precision: 5,  scale: 2, default: '0.00'
      t.decimal :igst_rate,   precision: 5,  scale: 2, default: '0.00'
      t.decimal :cgst_amount, precision: 14, scale: 2, default: '0.00'
      t.decimal :sgst_amount, precision: 14, scale: 2, default: '0.00'
      t.decimal :igst_amount, precision: 14, scale: 2, default: '0.00'
      t.decimal :tax_amount,  precision: 14, scale: 2, null: false, default: '0.00'

      t.decimal :line_total, precision: 14, scale: 2, null: false, default: '0.00'

      # Source references (optional linkage to order / stop)
      t.bigint  :source_sales_order_line_id
      t.bigint  :source_trip_stop_id

      t.jsonb :metadata, default: {}, null: false

      t.timestamps null: false
    end

    add_index :sales_invoice_lines, :sales_invoice_id,
              name: 'idx_sil_invoice_id'
    add_index :sales_invoice_lines, :source_sales_order_line_id,
              name: 'idx_sil_order_line_id'
    add_index :sales_invoice_lines, :source_trip_stop_id,
              name: 'idx_sil_stop_id'
    add_index :sales_invoice_lines, :product_id,
              name: 'idx_sil_product_id'

    # Track how many units have been invoiced per order line (prevents double-invoicing)
    add_column :sales_order_lines, :invoiced_qty, :decimal,
               precision: 14, scale: 3, null: false, default: '0.000'
    add_index  :sales_order_lines, :invoiced_qty, name: 'idx_sol_invoiced_qty'
  end
end
