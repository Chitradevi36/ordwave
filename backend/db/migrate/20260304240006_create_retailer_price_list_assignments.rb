class CreateRetailerPriceListAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :retailer_price_list_assignments do |t|
      t.references :customer,    null: false, foreign_key: { to_table: :customers }
      t.references :price_list,  null: false, foreign_key: { to_table: :price_lists }
      t.date    :starts_on
      t.date    :ends_on
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :retailer_price_list_assignments,
              [:customer_id, :price_list_id],
              unique: true,
              name: "idx_retailer_pl_assignment_unique"
    add_index :retailer_price_list_assignments, :active
  end
end
