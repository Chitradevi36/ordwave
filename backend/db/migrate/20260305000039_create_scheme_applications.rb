class CreateSchemeApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :scheme_applications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :sales_order, foreign_key: true   # nullable for preview
      t.references :scheme, null: false, foreign_key: true
      t.references :applied_by, foreign_key: { to_table: :users }

      t.string  :source, null: false, default: 'preview'  # preview | submit_snapshot

      t.jsonb   :breakdown, null: false, default: {}
      # { lines: [{product_id, discount_pct, discount_amount}],
      #   freebies: [{product_id, qty_free}],
      #   discount_total: 0.0,
      #   messages: ["Buy 10 get 1: triggered on SKU-001"] }

      t.datetime :applied_at, null: false

      t.timestamps
    end

    add_index :scheme_applications, [:sales_order_id, :source]
  end
end
