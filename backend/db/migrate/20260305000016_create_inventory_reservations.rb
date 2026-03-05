class CreateInventoryReservations < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_reservations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :product,      null: false, foreign_key: true

      # Reference the order that holds this reservation
      t.references :sales_order,  null: false, foreign_key: true
      t.bigint     :sales_order_line_id  # optional line-level trace

      t.decimal :qty_reserved, precision: 14, scale: 3, null: false
      t.string  :status, null: false, default: 'active'  # active | released | consumed

      t.timestamps
    end

    add_index :inventory_reservations,
              %i[branch_id product_id status],
              name: 'index_inventory_reservations_by_product_status'
    add_index :inventory_reservations, :sales_order_line_id,
              name: 'index_inventory_reservations_on_sales_order_line_id'
  end
end
