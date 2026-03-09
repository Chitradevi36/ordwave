# frozen_string_literal: true

class AddCessToSalesInvoiceLines < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_invoice_lines, :cess_rate, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :sales_invoice_lines, :cess_amount, :decimal, precision: 14, scale: 2, default: 0.0
  end
end
