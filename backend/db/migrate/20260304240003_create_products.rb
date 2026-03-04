class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.references :organization,      null: false, foreign_key: true
      t.references :product_category,  null: false, foreign_key: true
      t.references :units_of_measure,   null: false, foreign_key: true

      # Core fields
      t.string  :sku,          null: false
      t.string  :name,         null: false
      t.string  :barcode
      t.text    :description

      # HSN / GST  — FK into hsn_sac_codes master; gst_rate stored as snapshot
      t.references :hsn_sac_code, null: false, foreign_key: true
      t.decimal :gst_rate, precision: 5, scale: 2, null: false, default: 0

      # Pricing / ordering
      t.decimal :min_order_qty,   precision: 10, scale: 3, default: 1,    null: false
      t.decimal :purchase_price,  precision: 12, scale: 2  # hidden from sales reps
      t.decimal :weight_kg,       precision: 8,  scale: 3

      # Image
      t.string  :image_url

      # Status
      t.string  :status, default: 'active', null: false

      # Soft delete
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :products, [:organization_id, :sku],
              unique: true, where: "deleted_at IS NULL",
              name: "idx_products_org_sku_unique"
    add_index :products, :status
    add_index :products, :deleted_at
    add_index :products, :barcode, where: "barcode IS NOT NULL"
  end
end
