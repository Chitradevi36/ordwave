class CreateRescheduleDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :reschedule_deliveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :trip_stop, null: false, foreign_key: true
      t.references :sales_order, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.references :new_trip_stop, foreign_key: { to_table: :trip_stops }, optional: true
      
      # Dates
      t.date :original_date, null: false, comment: 'Original delivery date'
      t.date :next_retry_date, comment: 'Scheduled retry date'
      t.date :new_trip_date, comment: 'Date when rescheduled trip is scheduled'
      
      # Failure tracking
      t.string :failure_code, comment: 'Reason for delivery failure'
      t.text :failure_notes, comment: 'Additional notes about failure'
      t.integer :attempt_count, default: 1, comment: 'Number of delivery attempts'
      t.integer :max_attempts, default: 3, comment: 'Maximum retry attempts before escalation'
      
      # Status tracking
      t.string :status, default: 'pending', comment: 'pending | rescheduled | delivered | cancelled | escalated'
      
      # Timestamps
      t.datetime :last_attempted_at, comment: 'When last attempt was made'
      t.datetime :rescheduled_at, comment: 'When rescheduling was processed'
      
      t.timestamps
    end

    add_index :reschedule_deliveries, %i[trip_stop_id], unique: true
    add_index :reschedule_deliveries, %i[organization_id status], where: "status IN ('pending', 'rescheduled')", name: 'idx_reschedule_deliveries_pending'
    add_index :reschedule_deliveries, :next_retry_date, where: "status = 'pending'"
  end
end
