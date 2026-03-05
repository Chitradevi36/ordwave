class CreateDeliveryTrips < ActiveRecord::Migration[7.1]
  def change
    create_table :delivery_trips do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :vehicle,      null: true,  foreign_key: true
      t.bigint     :driver_id,    null: true
      t.string     :trip_number,  null: false
      t.date       :trip_date,    null: false
      t.string     :status,       null: false, default: 'draft'
      t.text       :notes
      t.string     :cancellation_reason
      t.datetime   :dispatched_at
      t.datetime   :completed_at

      t.timestamps
    end

    add_foreign_key :delivery_trips, :users, column: :driver_id
    add_index :delivery_trips, [:organization_id, :trip_number], unique: true
    add_index :delivery_trips, :status
    add_index :delivery_trips, :trip_date
    add_index :delivery_trips, :driver_id
  end
end
