# frozen_string_literal: true

class AddRazorpayFieldsToPayments < ActiveRecord::Migration[7.1]
  def change
    # Add fields to track Razorpay payments
    add_column :payments, :external_payment_id, :string, null: true, index: { unique: true, where: 'external_payment_id IS NOT NULL' }
    add_column :payments, :external_payload_data, :jsonb, null: true, default: {}
    add_column :payments, :external_payment_status, :string, null: true  # authorized, captured, failed, etc
    
    # Track when payment was confirmed  from Razorpay (separate from received_date which is for manual entry)
    add_column :payments, :external_confirmed_at, :datetime, null: true

    # Add index for finding unreconciled external payments
    add_index :payments, [:organization_id, :external_payment_status], name: 'idx_payments_org_ext_status'
  end
end
