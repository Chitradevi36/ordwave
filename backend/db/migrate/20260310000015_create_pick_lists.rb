class CreatePickLists < ActiveRecord::Migration[7.1]
  def change
    create_table :pick_lists do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :sales_order,  null: false, foreign_key: true
      t.references :picker, foreign_key: { to_table: :users }, null: true

      t.string   :status,       null: false, default: 'pending'
      t.string   :pick_number,  null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :pick_list_items do |t|
      t.references :pick_list, null: false, foreign_key: true
      t.references :product,   null: false, foreign_key: true

      t.integer  :qty_requested, null: false
      t.integer  :qty_picked,    null: false, default: 0
      t.string   :bin_location
      t.datetime :picked_at
      t.timestamps
    end

    add_index :pick_lists,      [:organization_id, :status]
    add_index :pick_lists,      [:organization_id, :pick_number], unique: true
    add_index :pick_list_items, [:pick_list_id, :product_id], unique: true
  end
end
