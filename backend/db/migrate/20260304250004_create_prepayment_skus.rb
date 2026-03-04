class CreatePrepaymentSkus < ActiveRecord::Migration[7.1]
  def change
    create_table :prepayment_skus do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :branch,       null: true,  foreign_key: true, index: true
      t.references :product,      null: false, foreign_key: true, index: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }, index: true
      t.text       :reason,         null: false
      t.date       :effective_from, null: false
      t.boolean    :active,         default: true, null: false

      t.timestamps

      # At most one active entry per (org, product) or per (org, branch, product)
      t.index [:organization_id, :product_id, :branch_id],
              name: "idx_prepayment_skus_active_unique",
              where: "active = true",
              unique: true
    end
  end
end
