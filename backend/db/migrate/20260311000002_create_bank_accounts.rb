# frozen_string_literal: true

class CreateBankAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_accounts do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :branch,       null: true,  foreign_key: true, index: true

      t.string  :bank_name,              null: false
      t.string  :account_name,           null: false
      t.string  :account_number_masked,  null: false  # last 4 digits visible, rest X
      t.string  :account_number_full,    null: true   # stored encrypted if needed
      t.string  :ifsc,                   null: true
      t.string  :status,                 null: false, default: "active"

      t.timestamps
    end

    add_index :bank_accounts, :status
  end
end
