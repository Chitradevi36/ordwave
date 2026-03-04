class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.string  :name,            null: false
      t.string  :code,            null: false
      t.string  :channel
      t.string  :tier
      t.decimal :credit_limit,    precision: 12, scale: 2, default: 0
      t.string  :gstin
      t.string  :pan
      t.string  :phone
      t.string  :email
      t.string  :status,          default: 'active', null: false
      t.references :branch,       null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :route,        foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :customers, :channel
    add_index :customers, :tier
    add_index :customers, :status
    add_index :customers, :deleted_at
    add_index :customers, %i[organization_id code], unique: true,
              name: 'idx_customers_org_code'
  end
end
