class CreatePriceLists < ActiveRecord::Migration[7.1]
  def change
    create_table :price_lists do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       foreign_key: true # null = org-wide standard; set = branch-specific
      t.string  :name,            null: false
      t.string  :list_type,       null: false, default: 'standard'
      # list_type: standard | promo | retailer_specific | tier_specific
      t.date    :valid_from
      t.date    :valid_to
      t.string  :status,          default: 'active', null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :price_lists, :list_type
    add_index :price_lists, :status
    add_index :price_lists, :deleted_at
    add_index :price_lists, [:branch_id, :list_type, :status],
              name: "idx_price_lists_branch_type_status"
  end
end
