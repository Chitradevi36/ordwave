class CreateStockTransferLines < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_transfer_lines do |t|
      t.references :stock_transfer, null: false, foreign_key: true
      t.references :product,        null: false, foreign_key: true
      t.decimal :qty_requested,  precision: 12, scale: 4, null: false
      t.decimal :qty_dispatched, precision: 12, scale: 4, null: false, default: 0
      t.decimal :qty_received,   precision: 12, scale: 4, null: false, default: 0
      t.decimal :qty_damaged,    precision: 12, scale: 4, null: false, default: 0
      t.string  :reason_code
      t.timestamps
    end

    add_index :stock_transfer_lines, [:stock_transfer_id, :product_id], unique: true
  end
end
