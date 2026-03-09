# frozen_string_literal: true

class AddCreditNoteAdjustmentFields < ActiveRecord::Migration[7.1]
  def change
    add_reference :credit_notes, :applied_to_invoice, foreign_key: { to_table: :sales_invoices }, null: true
    add_column :credit_notes, :unapplied_amount, :decimal, precision: 14, scale: 2, default: 0.0, null: false
    add_column :credit_notes, :applied_amount, :decimal, precision: 14, scale: 2, default: 0.0, null: false
    add_column :credit_notes, :adjustment_type, :string, default: 'manual' # manual, auto_next_invoice
  end
end
