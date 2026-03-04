class CreateCustomerContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_contacts do |t|
      t.references :customer,    null: false, foreign_key: true
      t.string  :name,         null: false
      t.string  :phone
      t.string  :email
      t.string  :designation
      t.boolean :is_primary,   default: false, null: false

      t.timestamps
    end

    add_index :customer_contacts, %i[customer_id is_primary],
              name: 'idx_customer_contacts_primary'
  end
end
