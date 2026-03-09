# frozen_string_literal: true

class AddReverseChargeToPurchaseInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :purchase_invoices, :is_reverse_charge, :boolean, default: false, null: false
    add_column :purchase_invoices, :rcm_tax_amount, :decimal, precision: 14, scale: 2, default: 0.0, null: false
    add_column :purchase_invoices, :supplier_gstin, :string
    add_column :purchase_invoices, :place_of_supply, :string
  end
end
