class AddNotificationDataToRescheduleDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_column :reschedule_deliveries, :notification_data, :jsonb, default: {}, null: false unless column_exists?(:reschedule_deliveries, :notification_data)
  end
end
