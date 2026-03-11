# frozen_string_literal: true

class CreateGstr1ExportRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :gstr1_export_records do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :branch,       null: true,  foreign_key: true, index: true
      t.references :generated_by, null: true,  foreign_key: { to_table: :users }, index: true

      # GST identifiers
      t.string  :gstin,          null: false
      t.string  :return_period,  null: false   # MMYYYY e.g. "032026"
      t.date    :period_from,    null: false
      t.date    :period_to,      null: false

      # Lifecycle
      t.string  :status,         null: false, default: 'pending'
      # pending | generating | ready | failed

      # Section counts (snapshot at generation time)
      t.integer :b2b_count,      null: false, default: 0
      t.integer :b2cl_count,     null: false, default: 0
      t.integer :b2cs_count,     null: false, default: 0
      t.integer :cdnr_count,     null: false, default: 0
      t.integer :cdnur_count,    null: false, default: 0
      t.integer :total_invoice_count, null: false, default: 0
      t.integer :total_cn_count,      null: false, default: 0

      # Value aggregates
      t.decimal :total_taxable_value, precision: 16, scale: 2, default: '0.0'
      t.decimal :total_tax_value,     precision: 16, scale: 2, default: '0.0'
      t.decimal :total_invoice_value, precision: 16, scale: 2, default: '0.0'

      # Validation report
      t.integer :error_count,   null: false, default: 0
      t.integer :warning_count, null: false, default: 0
      t.jsonb   :validation_report, null: false, default: {}

      # File
      t.string  :file_path
      t.string  :checksum         # SHA-256 of the generated JSON

      # Error
      t.text    :error_message
      t.datetime :completed_at

      t.timestamps null: false
    end

    add_index :gstr1_export_records, %i[organization_id return_period], name: 'idx_gstr1_exports_org_period'
    add_index :gstr1_export_records, :status
  end
end
