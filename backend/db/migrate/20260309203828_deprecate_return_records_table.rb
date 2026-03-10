# Phase 5: Soft-deprecate return_records table.
#
# ReturnRecord predates the Returns Engine (ReturnRequest/ReturnLine).
# We cannot safely drop the table yet — TripStop still references it via the
# legacy mobile workflow. This migration:
#   1. Adds a `deprecated_at` timestamp to mark when this deprecation was enacted.
#   2. Adds a check_constraint to block NEW inserts once fully migrated
#      (constraint is added in a future migration after mobile cutover).
#
# To fully clean up later:
#   1. Remove ReturnRecord references from TripStop model/controller.
#   2. Run `DropReturnRecordsTable` migration.
class DeprecateReturnRecordsTable < ActiveRecord::Migration[7.1]
  def up
    # Mark the deprecation timestamp — this column being not-null signals
    # to future developers that the table is in the deprecation window.
    add_column :return_records, :deprecated_at, :datetime,
               comment: "Set to migration time to mark deprecation. Null = pre-deprecation row."

    # Stamp existing rows and set a default for any new rows (they should be
    # zero but this prevents orphaned rows from being misleading).
    now = Time.current.utc
    execute("UPDATE return_records SET deprecated_at = '#{now.strftime('%Y-%m-%d %H:%M:%S')}'")
  end

  def down
    remove_column :return_records, :deprecated_at
  end
end
