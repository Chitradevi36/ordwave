class AddTallyFieldsToPaymentsAndCustomers < ActiveRecord::Migration[7.1]
  def change
    # Tally sync metadata on payments
    add_column :payments, :tally_voucher_number, :string, null: true
    add_column :payments, :tally_sync_at,        :datetime, null: true
    add_index  :payments, :tally_voucher_number, where: "tally_voucher_number IS NOT NULL"

    # Tally ledger mapping on customers
    add_column :customers, :tally_ledger_name,       :string,  null: true
    add_column :customers, :tally_closing_balance,   :decimal, precision: 15, scale: 2, null: true
    add_column :customers, :tally_balance_as_of_date, :date,   null: true
    add_index  :customers, :tally_ledger_name, where: "tally_ledger_name IS NOT NULL"
  end
end
