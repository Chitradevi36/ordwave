# frozen_string_literal: true

class CreateDeliveryRejections < ActiveRecord::Migration[7.1]
  def change
    create_table :delivery_rejections do |t|
      t.references :trip_stop, null: false, foreign_key: true
      t.references :sales_order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :rejected_by, null: false, foreign_key: { to_table: :users }
      t.decimal :qty_rejected, precision: 14, scale: 3, null: false
      t.string :reason_code, null: false # customer_refused, quality_issue, expired, short_supply, wrong_item, damaged, other
      t.string :condition, default: 'unopened', null: false # unopened, opened, damaged
      t.text :notes
      t.boolean :auto_return, default: true, null: false # auto-create return request
      t.bigint :return_request_id # link to auto-created return
      t.timestamps
    end

    add_index :delivery_rejections, :reason_code
    add_index :delivery_rejections, :return_request_id
  end
end
