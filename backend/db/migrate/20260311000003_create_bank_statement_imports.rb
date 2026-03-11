# frozen_string_literal: true

class CreateBankStatementImports < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_statement_imports do |t|
      t.references :organization,  null: false, foreign_key: true, index: true
      t.references :bank_account,  null: false, foreign_key: true, index: true
      t.references :uploaded_by,   null: true,  foreign_key: { to_table: :users }, index: true

      t.string  :file_name,          null: false
      t.string  :source_type,        null: false, default: "csv"
      t.string  :status,             null: false, default: "uploaded"
      t.integer :rows_count,         null: false, default: 0
      t.integer :processed_rows_count, null: false, default: 0
      t.integer :new_rows_count,     null: false, default: 0
      t.integer :duplicate_rows_count, null: false, default: 0
      t.integer :failed_rows_count,  null: false, default: 0
      t.text    :error_message

      t.timestamps
    end

    add_index :bank_statement_imports, :status
  end
end
