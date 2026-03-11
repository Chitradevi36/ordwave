# frozen_string_literal: true

class CreateGst2bImportLines < ActiveRecord::Migration[7.1]
  def change
    create_table :gst2b_import_lines do |t|
      t.bigint  :gst2b_import_id,          null: false
      t.bigint  :organization_id,           null: false
      t.string  :supplier_gstin,            null: false
      t.string  :supplier_name
      t.string  :invoice_number,            null: false
      t.date    :invoice_date
      t.decimal :invoice_value,             precision: 16, scale: 2, default: '0.0'
      t.decimal :taxable_value,             precision: 16, scale: 2, default: '0.0'
      t.decimal :igst,                      precision: 14, scale: 2, default: '0.0'
      t.decimal :cgst,                      precision: 14, scale: 2, default: '0.0'
      t.decimal :sgst,                      precision: 14, scale: 2, default: '0.0'
      t.decimal :cess,                      precision: 14, scale: 2, default: '0.0'
      t.string  :document_type,             default: 'invoice'
      # document_type: invoice / credit_note / debit_note / advance / isd
      t.string  :section_type,              default: 'b2b'
      # section_type: b2b / b2ba / cdn / cdna / isd / impg / impgsez
      t.string  :place_of_supply
      t.boolean :reverse_charge,            default: false, null: false
      t.boolean :itc_available,             default: true,  null: false
      t.string  :itc_reversal_reason
      t.bigint  :matched_purchase_invoice_id   # nullable until matched
      t.string  :match_status,              null: false, default: 'pending'
      # match_status: pending / matched / partial_match / multiple_candidates /
      #               missing_in_books / missing_in_2b / tax_mismatch /
      #               gstin_mismatch / date_mismatch / ignored
      t.decimal :match_confidence,          precision: 5, scale: 2
      t.jsonb   :match_explanation,         null: false, default: {}
      t.jsonb   :metadata,                  null: false, default: {}
      t.timestamps
    end

    add_index :gst2b_import_lines, :gst2b_import_id,
              name: 'idx_gst2b_lines_import_id'
    add_index :gst2b_import_lines, [:organization_id, :supplier_gstin, :invoice_number],
              name: 'idx_gst2b_lines_gstin_number'
    add_index :gst2b_import_lines, :match_status,
              name: 'idx_gst2b_lines_match_status'
    add_index :gst2b_import_lines, :matched_purchase_invoice_id,
              name: 'idx_gst2b_lines_matched_pi'
    add_index :gst2b_import_lines, :supplier_gstin
    add_index :gst2b_import_lines, :invoice_date

    add_foreign_key :gst2b_import_lines, :gst2b_imports
    add_foreign_key :gst2b_import_lines, :organizations
    add_foreign_key :gst2b_import_lines, :purchase_invoices,
                    column: :matched_purchase_invoice_id
  end
end
