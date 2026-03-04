class CreateProductCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :product_categories do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,            null: false
      t.string  :code
      t.text    :description
      t.boolean :active,      default: true, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :product_categories, [:organization_id, :name], unique: true,
              where: "deleted_at IS NULL",
              name: "idx_product_categories_org_name_unique"
    add_index :product_categories, :deleted_at
  end
end
