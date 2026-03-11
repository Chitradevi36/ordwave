# frozen_string_literal: true

class CreateBankTransactionMatches < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_transaction_matches do |t|
      t.references :bank_transaction, null: false, foreign_key: true, index: true
      t.references :customer,         null: true,  foreign_key: true, index: true
      t.references :sales_invoice,    null: true,  foreign_key: true, index: true

      t.decimal :score,           null: false, precision: 5, scale: 2
      t.string  :rule_code,       null: false
      t.jsonb   :explanation,     null: false, default: {}
      t.boolean :selected,        null: false, default: false

      t.timestamps
    end

    add_index :bank_transaction_matches, :rule_code
    add_index :bank_transaction_matches, :selected
  end
end
