class CreateReturnLines < ActiveRecord::Migration[7.1]
  def change
    create_table :return_lines do |t|
      t.references :return_request,   null: false, foreign_key: true
      t.references :product,          null: false, foreign_key: true
      t.references :sales_order_line, null: true,  foreign_key: true

      # Quantity
      t.decimal :qty_reported, precision: 14, scale: 3, null: false
      # qty_accepted / qty_rejected set during/after QC
      t.decimal :qty_accepted, precision: 14, scale: 3, null: false, default: 0
      t.decimal :qty_rejected, precision: 14, scale: 3, null: false, default: 0

      # Customer-reported classification
      t.string :condition_reported, null: false, default: 'unknown'
      # resalable | damaged | expired | unknown

      t.string :reason_code, null: false, default: 'other'
      # customer_refused | quality_issue | expired | short_supply | other

      # Price snapshots captured at submission time (for credit note valuation)
      t.decimal :unit_price_snapshot, precision: 14, scale: 2
      t.decimal :gst_rate_snapshot,   precision: 5,  scale: 2
      t.string  :hsn_code_snapshot

      t.timestamps
    end

    add_index :return_lines, %i[return_request_id product_id]
  end
end
