class AddShortageTrackingToSalesOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_orders, :rescheduled_at, :datetime, comment: 'When order was rescheduled due to shortage'
    add_column :sales_orders, :rescheduled_from, :datetime, comment: 'Original creation date before reschedule'
    add_column :sales_orders, :rescheduled_reason, :string, comment: 'Reason for reschedule (e.g., inventory_shortage)'
    add_column :sales_orders, :planned_delivery_date, :date, comment: 'Planned delivery date for rescheduled orders'
    
    add_index :sales_orders, :rescheduled_at
  end
end
