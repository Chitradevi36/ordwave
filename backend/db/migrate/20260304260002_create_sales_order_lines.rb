class CreateSalesOrderLines < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_order_lines do |t|
      t.references :sales_order, null: false, foreign_key: true
      t.references :product,     null: false, foreign_key: true

      t.decimal :qty,          precision: 14, scale: 3, null: false
      t.decimal :unit_price,   precision: 14, scale: 2, null: false
      t.decimal :discount_pct, precision: 5,  scale: 2, default: 0
      t.decimal :gst_rate,     precision: 5,  scale: 2, default: 0
      t.decimal :line_total,   precision: 14, scale: 2, null: false, default: 0

      t.string :price_source   # retailer_specific | tier_specific | promo | standard | manual | missing
      t.bigint :price_list_id
      t.string :hsn_code

      t.timestamps
    end

    add_index :sales_order_lines, :price_list_id
  end
end
