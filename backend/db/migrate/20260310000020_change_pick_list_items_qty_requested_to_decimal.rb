class ChangePickListItemsQtyRequestedToDecimal < ActiveRecord::Migration[7.1]
  # MED-05: pick_list_items.qty_requested was :integer which silently truncated
  # decimal order quantities (e.g. 2.5 kg → 2).  Changed to decimal(14,3) to
  # match sales_order_lines.qty precision.
  def up
    change_column :pick_list_items, :qty_requested, :decimal, precision: 14, scale: 3, null: false
    change_column :pick_list_items, :qty_picked,    :decimal, precision: 14, scale: 3, null: false, default: 0.0
  end

  def down
    change_column :pick_list_items, :qty_requested, :integer, null: false
    change_column :pick_list_items, :qty_picked,    :integer, null: false, default: 0
  end
end
