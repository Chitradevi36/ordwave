# frozen_string_literal: true

class CreateBankTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_transactions do |t|
      t.references :organization,          null: false, foreign_key: true, index: true
      t.references :bank_account,          null: false, foreign_key: true, index: true
      t.references :bank_statement_import, null: true,  foreign_key: true, index: true

      # Raw transaction fields from bank CSV
      t.date    :txn_date,          null: false
      t.decimal :amount,            null: false, precision: 15, scale: 2
      t.string  :direction,         null: false, default: "credit"  # credit | debit
      t.string  :utr_number
      t.string  :reference_number
      t.string  :payer_name
      t.text    :narration
      t.text    :normalized_narration
      t.jsonb   :raw_row_json,      null: false, default: {}
      t.jsonb   :match_meta,        null: false, default: {}

      # Match state
      t.string  :status,            null: false, default: "unmatched"
      t.decimal :match_score,       precision: 5, scale: 2
      t.string  :match_rule

      # Resolved foreign keys (set after matching/posting)
      t.bigint  :matched_customer_id
      t.bigint  :matched_invoice_id
      t.bigint  :matched_payment_id
      t.bigint  :reviewed_by_id

      t.text    :review_notes
      t.datetime :processed_at
      t.string  :idempotency_key,   null: false  # prevents duplicate imports

      t.timestamps

      t.index :status
      t.foreign_key :customers,     column: :matched_customer_id
      t.foreign_key :sales_invoices, column: :matched_invoice_id
      t.foreign_key :payments,       column: :matched_payment_id
      t.foreign_key :users,          column: :reviewed_by_id
    end

    add_index :bank_transactions, :utr_number
    add_index :bank_transactions, :amount
    add_index :bank_transactions, :txn_date
    add_index :bank_transactions, :idempotency_key, unique: true
    add_index :bank_transactions, :matched_customer_id
    add_index :bank_transactions, :matched_invoice_id
  end
end
