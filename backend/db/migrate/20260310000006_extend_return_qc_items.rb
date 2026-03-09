# frozen_string_literal: true

class ExtendReturnQcItems < ActiveRecord::Migration[7.1]
  def change
    add_column :return_qc_items, :qty_discounted_resalable, :decimal, precision: 14, scale: 3, default: 0.0, null: false
    add_column :return_qc_items, :qty_return_to_supplier, :decimal, precision: 14, scale: 3, default: 0.0, null: false
    add_column :return_qc_items, :discount_pct, :decimal, precision: 5, scale: 2 # for discounted resalable items
    add_column :return_qc_items, :supplier_return_reason, :string
  end
end
