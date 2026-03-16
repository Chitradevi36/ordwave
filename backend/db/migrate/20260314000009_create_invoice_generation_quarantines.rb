# frozen_string_literal: true

class CreateInvoiceGenerationQuarantines < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_generation_quarantines do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :trip_stop, null: false, foreign_key: true
      t.references :sales_order, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: { to_table: :branches }

      # Failure tracking
      t.text :error_message, null: false
      t.text :error_backtrace
      t.integer :retry_count, default: 0, null: false
      t.datetime :last_retry_at

      # Context for reprocessing
      t.jsonb :delivered_lines, null: false, default: {}, comment: 'Snapshot of delivered line items for retry'
      t.jsonb :error_context, default: {}, comment: 'Additional context (retry reason code, etc.)'

      # Status tracking
      t.string :status, default: 'quarantined', null: false, comment: 'quarantined, processing, resolved, archived'
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }, optional: true

      t.timestamps
    end

    add_index :invoice_generation_quarantines, [:organization_id, :status]
    add_index :invoice_generation_quarantines, [:created_at, :status]
    add_index :invoice_generation_quarantines, :trip_stop_id, unique: true, comment: 'One quarantine per trip stop'
  end
end
