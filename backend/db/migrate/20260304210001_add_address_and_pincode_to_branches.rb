class AddAddressAndPincodeToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :address, :string
    add_column :branches, :pincode, :string
    add_column :users, :plan, :string, default: 'starter', null: false
  end
end
