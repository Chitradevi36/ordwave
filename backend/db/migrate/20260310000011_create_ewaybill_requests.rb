# frozen_string_literal: true

class CreateEwaybillRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :ewaybill_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :sales_invoice, foreign_key: true
      t.string :requestable_type # SalesInvoice, StockTransfer
      t.bigint :requestable_id
      t.string :ewaybill_number
      t.string :status, default: 'pending', null: false # pending, generated, cancelled, expired, error
      t.string :transport_mode, default: 'road', null: false # road, rail, air, ship
      t.string :vehicle_number
      t.string :transporter_id
      t.string :transporter_name
      t.decimal :distance_km, precision: 10, scale: 2
      t.string :from_state
      t.string :to_state
      t.string :from_pincode
      t.string :to_pincode
      t.datetime :valid_from
      t.datetime :valid_until
      t.jsonb :response_json, default: {}
      t.text :error_message
      t.datetime :generated_at
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :ewaybill_requests, :ewaybill_number, unique: true, where: "ewaybill_number IS NOT NULL"
    add_index :ewaybill_requests, [:requestable_type, :requestable_id], name: 'idx_ewaybill_requestable'
    add_index :ewaybill_requests, :status
  end
end
