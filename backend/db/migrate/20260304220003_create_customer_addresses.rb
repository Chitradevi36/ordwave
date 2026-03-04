class CreateCustomerAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_addresses do |t|
      t.references :customer,    null: false, foreign_key: true
      t.string  :label,       default: 'billing'
      t.string  :line1
      t.string  :line2
      t.string  :city
      t.string  :state
      t.string  :postal_code
      t.string  :country,     default: 'India'
      t.decimal :latitude,    precision: 10, scale: 7
      t.decimal :longitude,   precision: 10, scale: 7

      t.timestamps
    end

    add_index :customer_addresses, :label
  end
end
