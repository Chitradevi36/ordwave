class AddDeviseToUsers < ActiveRecord::Migration[7.1]
  def up
    # Rename password_digest to encrypted_password for Devise
    rename_column :users, :password_digest, :encrypted_password

    # Add Devise trackable columns
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string

    # Add Devise recoverable columns
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # Add Devise rememberable column
    add_column :users, :remember_created_at, :datetime

    # Indexes
    add_index :users, :reset_password_token, unique: true
  end

  def down
    rename_column :users, :encrypted_password, :password_digest

    remove_column :users, :sign_in_count
    remove_column :users, :current_sign_in_at
    remove_column :users, :last_sign_in_at
    remove_column :users, :current_sign_in_ip
    remove_column :users, :last_sign_in_ip
    remove_column :users, :reset_password_token
    remove_column :users, :reset_password_sent_at
    remove_column :users, :remember_created_at
  end
end
