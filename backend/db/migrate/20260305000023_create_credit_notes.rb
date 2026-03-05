class CreateCreditNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_notes do |t|
      t.references :organization,    null: false, foreign_key: true
      t.references :branch,          null: false, foreign_key: true
      t.references :customer,        null: false, foreign_key: true
      t.references :return_request,  null: false, foreign_key: true
      t.references :sales_order,     null: true,  foreign_key: true
      t.references :created_by,      null: false, foreign_key: { to_table: :users }

      t.string  :credit_note_number, null: false
      t.string  :status,             null: false, default: 'draft'
      # draft | issued | void

      t.decimal :subtotal,   precision: 14, scale: 2, null: false, default: 0
      t.decimal :tax_total,  precision: 14, scale: 2, null: false, default: 0
      t.decimal :total,      precision: 14, scale: 2, null: false, default: 0

      t.text     :notes
      t.datetime :issued_at
      t.datetime :voided_at
      t.text     :void_reason

      # Soft delete
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :credit_notes, %i[organization_id credit_note_number], unique: true
    add_index :credit_notes, %i[customer_id status]
    add_index :credit_notes, %i[organization_id status]
    add_index :credit_notes, :deleted_at
  end
end
