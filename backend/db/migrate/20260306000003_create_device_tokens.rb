class CreateDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :device_tokens do |t|
      t.references :user,         null: false, foreign_key: true, index: true
      t.references :organization, null: false, foreign_key: true, index: true
      t.string     :token,        null: false
      t.string     :platform,     null: false   # ios | android | web
      t.string     :device_name
      t.boolean    :active,       null: false, default: true
      t.datetime   :last_used_at
      t.timestamps
    end

    add_index :device_tokens, [:user_id, :token],
              unique: true, name: "idx_device_tokens_user_token"
    add_index :device_tokens, [:organization_id, :active],
              name: "idx_device_tokens_org_active"
  end
end
