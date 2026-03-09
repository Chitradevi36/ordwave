# frozen_string_literal: true

class CreateCreditNoteApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_note_applications do |t|
      t.references :credit_note, null: false, foreign_key: true
      t.references :sales_invoice, null: false, foreign_key: true
      t.references :applied_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :status, default: 'active', null: false # active, reversed
      t.datetime :reversed_at
      t.text :reversal_reason
      t.timestamps
    end

    add_index :credit_note_applications, [:credit_note_id, :sales_invoice_id],
              name: 'idx_cn_applications_cn_invoice'
  end
end
