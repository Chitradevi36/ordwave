class AddDeliveredQtyToSalesOrderLines < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_order_lines, :delivered_qty,  :integer, default: 0, null: false
    add_column :sales_order_lines, :returned_qty,   :integer, default: 0, null: false
  end
end
