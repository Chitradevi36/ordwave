# frozen_string_literal: true

class CreateBulkGenerations < ActiveRecord::Migration[7.1]
  def change
    create_table :bulk_generations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :session_id, null: false, index: { unique: true }
      t.integer :total_count, null: false, default: 0
      t.integer :completed_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.string :status, null: false, default: 'in_progress'
      t.jsonb :errors, null: false, default: []
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    # Index for finding active bulk generations
    add_index :bulk_generations, [:organization_id, :completed_at], name: 'idx_bulk_gen_org_completed'
    # Index for cleanup queries
    add_index :bulk_generations, :created_at, name: 'idx_bulk_gen_created_at'
  end
end
