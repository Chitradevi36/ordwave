class CreateReturnRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :return_records do |t|
      t.references :trip_stop,   null: false, foreign_key: true
      t.references :product,     null: false, foreign_key: true
      t.integer    :qty_returned, null: false, default: 0
      t.string     :condition,   null: false, default: 'good'   # good | damaged | expired
      t.string     :reason_code, null: false                    # refused | not_home | short_delivery | quality | other
      t.text       :notes

      t.timestamps
    end

    add_index :return_records, :reason_code
    add_index :return_records, :condition
  end
end
