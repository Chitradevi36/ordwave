# frozen_string_literal: true

class CreateFinancialYears < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_years do |t|
      t.bigint  :organization_id,   null: false
      t.string  :code,              null: false  # "FY2025-26"
      t.string  :label,             null: false  # "2025-26"
      t.date    :start_date,        null: false  # 2025-04-01
      t.date    :end_date,          null: false  # 2026-03-31
      t.integer :starts_on_month,   null: false, default: 4
      t.integer :starts_on_day,     null: false, default: 1
      t.string  :status,            null: false, default: 'open'
      t.datetime :books_locked_at
      t.datetime :gst_locked_at
      t.datetime :closed_at
      t.bigint  :closed_by_id
      t.text    :notes
      t.jsonb   :metadata,          null: false, default: {}
      t.timestamps
    end

    add_index :financial_years, [:organization_id, :code],
              unique: true, name: 'idx_financial_years_org_code_unique'
    add_index :financial_years, [:organization_id, :status],
              name: 'idx_financial_years_org_status'
    add_index :financial_years, [:organization_id, :start_date],
              name: 'idx_financial_years_org_start_date'
    add_index :financial_years, :status
    add_index :financial_years, :closed_by_id

    add_foreign_key :financial_years, :organizations
    add_foreign_key :financial_years, :users, column: :closed_by_id
  end
end
