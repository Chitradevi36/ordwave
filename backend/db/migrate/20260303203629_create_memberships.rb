class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :role,         null: false, foreign_key: true
      t.boolean    :active,       null: false, default: true
      t.datetime   :deleted_at

      t.timestamps
    end
    add_index :memberships, [:user_id, :organization_id, :branch_id], unique: true, name: 'idx_memberships_unique'
    add_index :memberships, :deleted_at
  end
end
