class CreatePurchaseInvoiceLines < ActiveRecord::Migration[7.1]
  def change
    create_table :purchase_invoice_lines do |t|
      t.references :purchase_invoice, null: false, foreign_key: true
      t.references :product,          null: false, foreign_key: true
      t.decimal :qty,                 precision: 14, scale: 3, null: false
      t.decimal :unit_price,          precision: 14, scale: 2, null: false
      t.decimal :discount_pct,        precision: 5,  scale: 2, null: false, default: 0
      t.decimal :tax_rate,            precision: 5,  scale: 2, null: false, default: 0
      t.decimal :tax_amount,          precision: 14, scale: 2, null: false, default: 0
      t.decimal :line_total,          precision: 14, scale: 2, null: false, default: 0
      t.references :hsn_sac_code, null: true, foreign_key: true
      t.text    :notes
      t.timestamps
    end
  end
end
