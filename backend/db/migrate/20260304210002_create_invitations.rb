class CreateInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :invitations do |t|
      t.string   :email,           null: false
      t.string   :token_digest,    null: false
      t.bigint   :organization_id, null: false
      t.bigint   :role_id,         null: false
      t.bigint   :branch_id
      t.bigint   :invited_by_id,   null: false
      t.string   :status,          null: false, default: 'pending'
      t.datetime :expires_at,      null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true
    add_index :invitations, :organization_id
    add_index :invitations, :invited_by_id
    add_index :invitations, %i[organization_id email], name: :idx_invitations_org_email

    add_foreign_key :invitations, :organizations
    add_foreign_key :invitations, :roles
    add_foreign_key :invitations, :branches
    add_foreign_key :invitations, :users, column: :invited_by_id
  end
end
