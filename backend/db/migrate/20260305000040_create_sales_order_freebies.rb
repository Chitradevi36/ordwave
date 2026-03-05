class CreateSalesOrderFreebies < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_order_freebies do |t|
      t.references :sales_order, null: false, foreign_key: true
      t.references :scheme, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :qty_free,       precision: 14, scale: 3, null: false
      t.string  :uom
      t.text    :notes

      t.timestamps
    end
  end
end
