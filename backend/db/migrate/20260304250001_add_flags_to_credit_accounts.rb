class AddFlagsToCreditAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :credit_accounts, :collection_first,       :boolean, default: false, null: false
    add_column :credit_accounts, :hold_required,           :boolean, default: false, null: false
    add_column :credit_accounts, :watchlist,               :boolean, default: false, null: false
    add_column :credit_accounts, :overdue_bucket_cached,   :string
  end
end
