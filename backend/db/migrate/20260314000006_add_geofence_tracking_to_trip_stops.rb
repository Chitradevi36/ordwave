class AddGeofenceTrackingToTripStops < ActiveRecord::Migration[7.1]
  def change
    # Add geofence validation fields to trip_stops table
    add_column :trip_stops, :geofence_status, :string, default: 'not_checked', comment: 'within_geofence | outside_geofence | not_checked | invalid'
    add_column :trip_stops, :geofence_distance_m, :decimal, precision: 10, scale: 2, comment: 'Distance in meters from customer address'
    add_column :trip_stops, :geofence_validated_at, :datetime, comment: 'Timestamp when geofence validation was performed'
    
    # Add index for geofence queries
    add_index :trip_stops, :geofence_status, where: "geofence_status IN ('outside_geofence', 'not_checked')", name: 'idx_trip_stops_geofence_anomalies'
  end
end
