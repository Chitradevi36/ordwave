# Adds vehicle + default driver assignments to routes, and a route reference
# to delivery_trips so that trips can be matched per-route.
#
# - routes.vehicle_id         – preferred vehicle for this route (optional)
# - routes.default_driver_id  – preferred driver for this route (optional);
#                               falls back to vehicle.default_driver when blank
# - delivery_trips.route_id   – route this trip serves (set on auto-creation)
class AddRouteVehicleDriverToRoutesAndTrips < ActiveRecord::Migration[7.1]
  def change
    # Route → vehicle / driver
    add_reference :routes, :vehicle,        foreign_key: true,  null: true
    add_reference :routes, :default_driver, foreign_key: { to_table: :users }, null: true

    # DeliveryTrip → route  (nullable; manually-created trips may have no route)
    add_reference :delivery_trips, :route, foreign_key: true, null: true
  end
end
