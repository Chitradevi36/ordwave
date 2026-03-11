# frozen_string_literal: true

class CreateGstReturnPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :gst_return_periods do |t|
      t.bigint  :organization_id,      null: false
      t.bigint  :branch_id                          # nullable = all-branches period
      t.bigint  :financial_year_id,    null: false
      t.string  :financial_year_label               # cached e.g. "2025-26"
      t.integer :month,                null: false  # 1-12 calendar month
      t.integer :year,                 null: false  # calendar year
      t.date    :period_start_on,      null: false
      t.date    :period_end_on,        null: false
      t.string  :return_type,          null: false  # gstr1 / gstr3b / gstr2b_import
      t.string  :status,               null: false, default: 'draft'
      # status enum: draft / generated / reviewed / locked / filed
      t.datetime :generated_at
      t.datetime :locked_at
      t.datetime :filed_at
      t.bigint   :filed_by_id
      t.bigint   :locked_by_id
      t.bigint   :reviewed_by_id
      t.string   :source_hash           # hash of input invoice IDs — detects drift
      t.string   :snapshot_hash         # hash of snapshot payload
      t.text     :filing_notes
      t.integer  :error_count,          null: false, default: 0
      t.integer  :warning_count,        null: false, default: 0
      t.jsonb    :metadata,             null: false, default: {}
      t.timestamps
    end

    add_index :gst_return_periods,
              [:organization_id, :financial_year_id, :month, :year, :return_type, :branch_id],
              unique: true, name: 'idx_gst_return_periods_unique',
              where: 'branch_id IS NOT NULL'
    add_index :gst_return_periods,
              [:organization_id, :financial_year_id, :month, :year, :return_type],
              unique: true, name: 'idx_gst_return_periods_unique_no_branch',
              where: 'branch_id IS NULL'
    add_index :gst_return_periods, [:organization_id, :status],
              name: 'idx_gst_return_periods_org_status'
    add_index :gst_return_periods, [:organization_id, :return_type, :year, :month],
              name: 'idx_gst_return_periods_org_type_period'
    add_index :gst_return_periods, :financial_year_id
    add_index :gst_return_periods, :branch_id
    add_index :gst_return_periods, :status
    add_index :gst_return_periods, :filed_by_id

    add_foreign_key :gst_return_periods, :organizations
    add_foreign_key :gst_return_periods, :financial_years
    add_foreign_key :gst_return_periods, :branches, column: :branch_id
    add_foreign_key :gst_return_periods, :users, column: :filed_by_id
    add_foreign_key :gst_return_periods, :users, column: :locked_by_id
    add_foreign_key :gst_return_periods, :users, column: :reviewed_by_id
  end
end
