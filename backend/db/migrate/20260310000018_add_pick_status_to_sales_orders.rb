class AddPickStatusToSalesOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_orders, :pick_status, :integer, null: false, default: 0
    add_column :sales_orders, :picked_by_id, :bigint
    add_column :sales_orders, :picked_at, :datetime
    add_column :sales_orders, :pick_confirmed_by_id, :bigint
    add_column :sales_orders, :pick_confirmed_at, :datetime

    add_index :sales_orders, :pick_status
    add_foreign_key :sales_orders, :users, column: :picked_by_id
    add_foreign_key :sales_orders, :users, column: :pick_confirmed_by_id
  end
end
