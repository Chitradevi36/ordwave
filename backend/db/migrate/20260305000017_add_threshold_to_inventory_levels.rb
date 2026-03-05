class AddThresholdToInventoryLevels < ActiveRecord::Migration[7.1]
  def change
    add_column :inventory_levels, :min_qty_threshold, :decimal,
               precision: 14, scale: 3, default: nil
  end
end
