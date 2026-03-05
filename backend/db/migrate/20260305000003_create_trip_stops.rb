class CreateTripStops < ActiveRecord::Migration[7.1]
  def change
    create_table :trip_stops do |t|
      t.references :delivery_trip, null: false, foreign_key: true
      t.references :sales_order,   null: false, foreign_key: true
      t.integer    :sequence,      null: false, default: 0
      t.string     :status,        null: false, default: 'pending'
      t.datetime   :delivered_at
      t.decimal    :latitude,   precision: 9, scale: 6
      t.decimal    :longitude,  precision: 9, scale: 6
      t.string     :device_id
      t.string     :exception_code
      t.text       :delivery_notes
      t.string     :idempotency_key
      t.datetime   :deleted_at

      t.timestamps
    end

    add_index :trip_stops, :status
    add_index :trip_stops, :idempotency_key, unique: true, where: 'idempotency_key IS NOT NULL'
    add_index :trip_stops, [:delivery_trip_id, :sequence]
  end
end
