# frozen_string_literal: true

class CreateGstAmendmentCandidates < ActiveRecord::Migration[7.1]
  def change
    create_table :gst_amendment_candidates do |t|
      t.references :organization,      null: false, foreign_key: true
      t.references :gst_return_period, null: false, foreign_key: true

      # Polymorphic source document (SalesInvoice or CreditNote)
      t.string  :source_type, null: false
      t.bigint  :source_id,   null: false

      # What kind of amendment is this?
      # new_invoice / modified_invoice / new_cn / modified_cn / cancelled_invoice
      t.string :amendment_type, null: false

      # Lifecycle: detected → acknowledged → included_in_amendment | dismissed
      t.string :status, null: false, default: 'detected'

      # Values at the time the original return was filed vs current values
      t.decimal :taxable_value_original, precision: 16, scale: 2
      t.decimal :taxable_value_current,  precision: 16, scale: 2
      t.decimal :tax_original,           precision: 16, scale: 2
      t.decimal :tax_current,            precision: 16, scale: 2

      # Human-readable summary, e.g. "Modified Invoice: INV-00123"
      t.text :change_summary

      t.datetime :detected_at, null: false

      # CA / user who acknowledged it
      t.bigint   :acknowledged_by_id
      t.datetime :acknowledged_at

      # Extra context — stores the diff payload, hash comparison, etc.
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :gst_amendment_candidates, [:organization_id, :gst_return_period_id],
              name: 'idx_gst_amc_on_org_and_period'
    add_index :gst_amendment_candidates, [:source_type, :source_id],
              name: 'idx_gst_amc_on_source'
    add_index :gst_amendment_candidates, :status,
              name: 'idx_gst_amc_on_status'
    add_index :gst_amendment_candidates, [:gst_return_period_id, :amendment_type],
              name: 'idx_gst_amc_on_period_and_type'

    add_foreign_key :gst_amendment_candidates, :users,
                    column: :acknowledged_by_id, on_delete: :nullify
  end
end
