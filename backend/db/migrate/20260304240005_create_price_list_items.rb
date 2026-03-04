class CreatePriceListItems < ActiveRecord::Migration[7.1]
  def change
    create_table :price_list_items do |t|
      t.references :price_list, null: false, foreign_key: true
      t.references :product,    null: false, foreign_key: true
      t.decimal :unit_price,    precision: 12, scale: 2, null: false
      t.decimal :min_qty,       precision: 10, scale: 3  # nil = base price (applies to qty >= 1)
      t.decimal :discount_pct,  precision: 5,  scale: 2, default: 0

      t.timestamps
    end

    # Unique: one item per (price_list, product, min_qty) combination
    add_index :price_list_items, [:price_list_id, :product_id, :min_qty],
              unique: true, name: "idx_price_list_items_unique"
  end
end
