class AddSchemeSnapshotToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_orders, :scheme_snapshot, :jsonb, default: {}
    # Frozen scheme application summary persisted at submit time.
    # Shape: { applied: [{scheme_id, code, name, discount_total, freebies}],
    #          not_applied: [{scheme_id, code, name, reason}],
    #          discount_total: 0.0 }
  end
end
