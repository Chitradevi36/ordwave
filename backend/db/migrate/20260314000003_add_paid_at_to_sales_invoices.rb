# frozen_string_literal: true

class AddPaidAtToSalesInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_invoices, :paid_at, :datetime, null: true

    # Add index for finding paid invoices
    add_index :sales_invoices, [:organization_id, :paid_at], name: 'idx_sales_invoices_org_paid_at'
  end
end
