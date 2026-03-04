class AddStatusToMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :memberships, :status, :string, null: false, default: 'active'
    add_index  :memberships, :status
  end
end
