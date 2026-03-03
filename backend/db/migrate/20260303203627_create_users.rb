class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :encrypted_password
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.boolean :active

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
