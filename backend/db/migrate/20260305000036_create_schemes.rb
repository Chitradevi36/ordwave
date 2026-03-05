class CreateSchemes < ActiveRecord::Migration[7.1]
  def change
    create_table :schemes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       foreign_key: true   # nil = org-wide
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      t.string  :name,        null: false
      t.string  :code,        null: false
      t.string  :scheme_type, null: false           # buy_x_get_y | slab_discount | item_discount | order_value_discount
      t.string  :status,      null: false, default: 'active'   # active | inactive | expired
      t.integer :priority,    null: false, default: 0
      t.boolean :exclusive,   null: false, default: false

      t.date    :start_date
      t.date    :end_date
      t.integer :applicable_days, array: true, default: []     # 0=Mon…6=Sun

      t.string  :applies_to, null: false, default: 'all'       # all | retailer_segment | specific_retailers | route | beat

      t.text    :notes
      t.jsonb   :metadata,   null: false, default: {}

      t.timestamps
    end

    add_index :schemes, [:organization_id, :code], unique: true
    add_index :schemes, :status
    add_index :schemes, :scheme_type
    add_index :schemes, [:start_date, :end_date]
  end
end
