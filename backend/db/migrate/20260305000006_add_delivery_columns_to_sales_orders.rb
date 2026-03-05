class AddDeliveryColumnsToSalesOrders < ActiveRecord::Migration[7.1]
  def change
    # New status values: dispatched, delivered, partial_delivery
    # No constraint change needed in Postgres — Rails enum is validated at app layer
    add_column :sales_orders, :dispatched_at,        :datetime
    add_column :sales_orders, :delivered_at,          :datetime
    add_column :sales_orders, :delivery_failure_reason, :text
  end
end
