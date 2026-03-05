class CreateCreditNoteLines < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_note_lines do |t|
      t.references :credit_note,   null: false, foreign_key: true
      t.references :product,       null: false, foreign_key: true
      t.references :return_line,   null: true,  foreign_key: true

      t.decimal :qty,        precision: 14, scale: 3, null: false
      t.decimal :unit_price, precision: 14, scale: 2, null: false
      t.decimal :gst_rate,   precision: 5,  scale: 2, null: false, default: 0
      t.decimal :tax_amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :line_total, precision: 14, scale: 2, null: false, default: 0
      t.string  :hsn_code

      t.timestamps
    end
  end
end
