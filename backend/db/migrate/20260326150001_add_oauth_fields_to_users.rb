class AddOauthFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :oauth_provider, :string, comment: 'OAuth provider (google, microsoft, apple, etc)'
    add_column :users, :oauth_uid, :string, comment: 'Unique identifier from OAuth provider'
    
    # Add index for faster lookups on OAuth logins
    add_index :users, [:oauth_provider, :oauth_uid], unique: true, where: "oauth_provider IS NOT NULL", name: 'idx_users_oauth_provider_uid'
    
    # Make oauth_provider and oauth_uid nullable (users can have either email/password or OAuth)
    # No validation needed here; validations happen in User model
  end
end
