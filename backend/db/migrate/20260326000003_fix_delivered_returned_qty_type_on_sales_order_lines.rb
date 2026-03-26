# frozen_string_literal: true

# Tier 2 #21 — Fix integer → decimal type mismatch on sales_order_lines.
#
# `qty` is decimal(14,3) but `delivered_qty` and `returned_qty` were added
# as integer, silently truncating fractional delivery/return quantities.
# This changes them to decimal(14,3) matching `qty` and `invoiced_qty`.
class FixDeliveredReturnedQtyTypeOnSalesOrderLines < ActiveRecord::Migration[7.1]
  def up
    change_column :sales_order_lines, :delivered_qty, :decimal,
                  precision: 14, scale: 3, default: 0.0, null: false

    change_column :sales_order_lines, :returned_qty, :decimal,
                  precision: 14, scale: 3, default: 0.0, null: false
  end

  def down
    change_column :sales_order_lines, :delivered_qty, :integer, default: 0, null: false
    change_column :sales_order_lines, :returned_qty, :integer, default: 0, null: false
  end
end
