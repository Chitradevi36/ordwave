class CreateInventoryLevels < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_levels do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :product,      null: false, foreign_key: true
      t.decimal :qty_on_hand,     precision: 14, scale: 3, null: false, default: 0
      t.decimal :qty_reserved,    precision: 14, scale: 3, null: false, default: 0
      t.timestamps
    end

    add_index :inventory_levels, %i[branch_id product_id],
              unique: true, name: 'index_inventory_levels_branch_product'
  end
end
