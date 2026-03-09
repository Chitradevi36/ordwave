# frozen_string_literal: true

class CreateSupplierDebitNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_debit_notes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :return_request, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :debit_note_number, null: false
      t.date :debit_note_date, null: false
      t.string :status, default: 'draft', null: false # draft, issued, void
      t.string :reason, null: false # quality_issue, expired, short_supply, damaged, wrong_item
      t.decimal :subtotal, precision: 14, scale: 2, default: 0.0, null: false
      t.decimal :tax_total, precision: 14, scale: 2, default: 0.0, null: false
      t.decimal :total, precision: 14, scale: 2, default: 0.0, null: false
      t.text :notes
      t.datetime :issued_at
      t.datetime :voided_at
      t.text :void_reason
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :supplier_debit_notes, [:organization_id, :debit_note_number],
              unique: true, name: 'idx_sdn_org_number'
    add_index :supplier_debit_notes, :status
    add_index :supplier_debit_notes, :deleted_at

    create_table :supplier_debit_note_lines do |t|
      t.references :supplier_debit_note, null: false, foreign_key: true, index: { name: 'idx_sdnl_debit_note' }
      t.references :product, null: false, foreign_key: true
      t.references :return_line, foreign_key: true
      t.decimal :qty, precision: 14, scale: 3, null: false
      t.decimal :unit_price, precision: 14, scale: 2, null: false
      t.decimal :gst_rate, precision: 5, scale: 2, default: 0.0, null: false
      t.decimal :tax_amount, precision: 14, scale: 2, default: 0.0, null: false
      t.decimal :line_total, precision: 14, scale: 2, default: 0.0, null: false
      t.string :hsn_code
      t.string :batch_number
      t.date :expiry_date
      t.timestamps
    end
  end
end
