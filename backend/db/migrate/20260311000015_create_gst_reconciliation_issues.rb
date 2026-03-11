# frozen_string_literal: true

class CreateGstReconciliationIssues < ActiveRecord::Migration[7.1]
  def change
    create_table :gst_reconciliation_issues do |t|
      t.bigint  :organization_id,       null: false
      t.bigint  :branch_id
      t.bigint  :financial_year_id,     null: false
      t.bigint  :gst_return_period_id
      t.bigint  :gst2b_import_id
      t.string  :issue_type,            null: false
      # issue_type:
      #   missing_in_2b / missing_in_books / tax_mismatch / date_mismatch /
      #   gstin_mismatch / invoice_value_mismatch / duplicate_invoice /
      #   invalid_hsn / missing_gstin / reverse_charge_mismatch / itc_risk
      t.string  :severity,              null: false, default: 'medium'
      # severity: blocking / high / medium / low
      t.string  :source_type            # 'SalesInvoice' / 'PurchaseInvoice' / 'Gst2bImportLine'
      t.bigint  :source_id
      t.string  :counterpart_type       # the other side of the comparison
      t.bigint  :counterpart_id
      t.string  :supplier_gstin
      t.string  :customer_gstin
      t.string  :invoice_number
      t.date    :invoice_date
      t.decimal :amount_books,          precision: 16, scale: 2
      t.decimal :amount_portal,         precision: 16, scale: 2
      t.decimal :difference_amount,     precision: 16, scale: 2
      t.string  :status,                null: false, default: 'open'
      # status: open / acknowledged / resolved / ignored
      t.text    :resolution_notes
      t.bigint  :resolved_by_id
      t.datetime :resolved_at
      t.jsonb   :metadata,              null: false, default: {}
      t.timestamps
    end

    add_index :gst_reconciliation_issues,
              [:organization_id, :financial_year_id, :issue_type],
              name: 'idx_gst_recon_issues_org_fy_type'
    add_index :gst_reconciliation_issues,
              [:organization_id, :status],
              name: 'idx_gst_recon_issues_org_status'
    add_index :gst_reconciliation_issues, :gst_return_period_id
    add_index :gst_reconciliation_issues, :gst2b_import_id
    add_index :gst_reconciliation_issues, :financial_year_id
    add_index :gst_reconciliation_issues, :severity
    add_index :gst_reconciliation_issues, :status
    add_index :gst_reconciliation_issues, [:source_type, :source_id],
              name: 'idx_gst_recon_issues_source'
    add_index :gst_reconciliation_issues, :resolved_by_id

    add_foreign_key :gst_reconciliation_issues, :organizations
    add_foreign_key :gst_reconciliation_issues, :financial_years
    add_foreign_key :gst_reconciliation_issues, :gst_return_periods
    add_foreign_key :gst_reconciliation_issues, :gst2b_imports
    add_foreign_key :gst_reconciliation_issues, :users, column: :resolved_by_id
  end
end
