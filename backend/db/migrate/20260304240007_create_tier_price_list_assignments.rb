class CreateTierPriceListAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :tier_price_list_assignments do |t|
      t.references :branch,     null: false, foreign_key: true
      t.references :price_list, null: false, foreign_key: true
      t.string  :retailer_tier, null: false  # platinum|gold|silver|bronze
      t.date    :starts_on
      t.date    :ends_on
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :tier_price_list_assignments,
              [:branch_id, :retailer_tier, :price_list_id],
              unique: true,
              name: "idx_tier_pl_assignment_unique"
    add_index :tier_price_list_assignments, [:branch_id, :retailer_tier],
              name: "idx_tier_pl_assignment_branch_tier"
  end
end
