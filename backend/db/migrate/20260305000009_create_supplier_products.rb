class CreateSupplierProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_products do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :product,  null: false, foreign_key: true

      t.decimal :purchase_price, precision: 15, scale: 2
      t.string  :supplier_sku
      t.integer :lead_time_days

      t.timestamps
    end

    add_index :supplier_products, %i[supplier_id product_id], unique: true,
              name: 'index_supplier_products_on_supplier_and_product'
  end
end
