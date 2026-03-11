# frozen_string_literal: true

class CreateExpectedPaymentReferences < ActiveRecord::Migration[7.1]
  def change
    create_table :expected_payment_references do |t|
      t.references :organization,  null: false, foreign_key: true, index: true
      t.references :customer,      null: true,  foreign_key: true, index: true
      t.references :sales_invoice, null: true,  foreign_key: true, index: true

      # reference_type: utr | invoice_number | customer_code | custom
      t.string :reference_type,  null: false
      t.string :reference_value, null: false
      # status: pending | matched | expired
      t.string :status,          null: false, default: "pending"

      t.timestamps
    end

    add_index :expected_payment_references, :reference_value
    add_index :expected_payment_references, :status
  end
end
