class CreateSuppliers < ActiveRecord::Migration[7.1]
  def change
    create_table :suppliers do |t|
      t.references :organization, null: false, foreign_key: true

      # Identity
      t.string  :name,             null: false, limit: 200
      t.string  :code,             null: false
      t.string  :status,           null: false, default: 'active'

      # Contact
      t.string  :phone,            null: false
      t.string  :email
      t.string  :contact_person

      # Tax & Legal
      t.string  :gstin,            limit: 15
      t.string  :pan,              limit: 10

      # Address
      t.string  :address
      t.string  :city
      t.string  :state
      t.string  :pincode

      # Banking
      t.string  :bank_name
      t.string  :bank_account
      t.string  :bank_ifsc

      # Commercial
      t.integer :payment_terms_days, null: false, default: 30
      t.decimal :credit_limit,       precision: 15, scale: 2, default: '0.0', null: false
      t.text    :notes

      # Soft delete
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :suppliers, :gstin
    add_index :suppliers, %i[organization_id name]
    # Partial unique index — code must be unique per org among non-deleted rows
    add_index :suppliers, %i[organization_id code],
              unique: true,
              where:  'deleted_at IS NULL',
              name:   'index_suppliers_on_org_code_unique'
  end
end
