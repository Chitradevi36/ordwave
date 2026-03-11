# frozen_string_literal: true

class CreateGstReturnSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :gst_return_snapshots do |t|
      t.bigint  :gst_return_period_id, null: false
      t.bigint  :organization_id,      null: false
      t.string  :section_key,          null: false
      # section_key examples: 'b2b', 'b2cl', 'b2cs', 'cdnr', 'cdnur', 'hsn',
      #                        'nil_exempt', 'gstr3b', 'full'
      t.jsonb   :payload,              null: false, default: {}
      t.jsonb   :totals,               null: false, default: {}
      t.jsonb   :source_counts,        null: false, default: {}
      t.jsonb   :source_invoice_ids,   null: false, default: []
      t.datetime :generated_at,        null: false
      t.integer  :version_number,      null: false, default: 1
      t.string   :source_hash          # hash of invoice IDs at generation time
      t.string   :snapshot_hash        # hash of payload — integrity check
      t.boolean  :is_filed,            null: false, default: false
      t.jsonb    :metadata,            null: false, default: {}
      t.timestamps
    end

    add_index :gst_return_snapshots, [:gst_return_period_id, :section_key, :version_number],
              name: 'idx_gst_snapshots_period_section_version'
    add_index :gst_return_snapshots, [:gst_return_period_id, :is_filed],
              name: 'idx_gst_snapshots_period_filed'
    add_index :gst_return_snapshots, :organization_id
    add_index :gst_return_snapshots, :generated_at

    add_foreign_key :gst_return_snapshots, :gst_return_periods
    add_foreign_key :gst_return_snapshots, :organizations
  end
end
