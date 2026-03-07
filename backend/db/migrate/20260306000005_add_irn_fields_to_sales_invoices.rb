class AddIrnFieldsToSalesInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_invoices, :irn,                :string,  comment: "Invoice Reference Number from GST IRP"
    add_column :sales_invoices, :irn_generated_at,   :datetime
    add_column :sales_invoices, :ack_number,         :string,  comment: "IRP acknowledgement number"
    add_column :sales_invoices, :ack_datetime,        :string
    add_column :sales_invoices, :einvoice_qr_code,   :text,    comment: "Signed QR code from IRP"
    add_column :sales_invoices, :einvoice_status,    :string,  default: "not_required"
    add_column :sales_invoices, :einvoice_error,     :text

    add_index :sales_invoices, :irn,
              unique: true,
              where:  "irn IS NOT NULL",
              name:   "idx_sales_invoices_irn_unique"
  end
end
