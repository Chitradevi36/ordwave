# frozen_string_literal: true

class CreateGst2bImports < ActiveRecord::Migration[7.1]
  def change
    create_table :gst2b_imports do |t|
      t.bigint  :organization_id,      null: false
      t.bigint  :branch_id                          # nil = all-org import
      t.bigint  :financial_year_id,    null: false
      t.string  :financial_year_label               # cached
      t.integer :month,                null: false  # 1-12
      t.integer :year,                 null: false
      t.date    :period_start_on,      null: false
      t.date    :period_end_on,        null: false
      t.string  :gstin,                null: false  # recipient GSTIN (buyer)
      t.string  :file_name
      t.string  :source_type,          null: false, default: 'json'
      # source_type: json / excel / csv / api_placeholder
      t.string  :import_status,        null: false, default: 'uploaded'
      # import_status: uploaded / parsing / parsed / matching / completed / failed
      t.jsonb   :raw_payload,          null: false, default: {}
      t.jsonb   :parsed_summary,       null: false, default: {}
      t.integer :total_rows,           null: false, default: 0
      t.integer :matched_rows,         null: false, default: 0
      t.integer :unmatched_rows,       null: false, default: 0
      t.integer :error_rows,           null: false, default: 0
      t.datetime :imported_at
      t.bigint  :imported_by_id
      t.string  :source_hash           # hash of raw file content — dedup detection
      t.text    :error_message
      t.jsonb   :metadata,             null: false, default: {}
      t.timestamps
    end

    add_index :gst2b_imports, [:organization_id, :financial_year_id, :month, :year],
              name: 'idx_gst2b_imports_org_fy_period'
    add_index :gst2b_imports, [:organization_id, :source_hash],
              name: 'idx_gst2b_imports_source_hash'
    add_index :gst2b_imports, :import_status
    add_index :gst2b_imports, :financial_year_id
    add_index :gst2b_imports, :branch_id
    add_index :gst2b_imports, :imported_by_id

    add_foreign_key :gst2b_imports, :organizations
    add_foreign_key :gst2b_imports, :financial_years
    add_foreign_key :gst2b_imports, :branches, column: :branch_id
    add_foreign_key :gst2b_imports, :users, column: :imported_by_id
  end
end
