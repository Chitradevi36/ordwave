# frozen_string_literal: true

class RemoveDuplicateSalesInvoiceLineIndexes < ActiveRecord::Migration[7.1]
  def change
    # idx_sil_product_id already covers the same column
    remove_index :sales_invoice_lines, name: :index_sales_invoice_lines_on_product_id, if_exists: true

    # idx_sil_invoice_id already covers the same column
    remove_index :sales_invoice_lines, name: :index_sales_invoice_lines_on_sales_invoice_id, if_exists: true
  end
end
