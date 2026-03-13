class AddBillingFieldsToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :billing_status,       :string,   default: "inactive", null: false
    add_column :organizations, :razorpay_customer_id, :string
    add_column :organizations, :current_period_end,   :datetime
    add_column :organizations, :trial_ends_at,        :datetime

    add_index :organizations, :razorpay_customer_id, unique: true, where: "razorpay_customer_id IS NOT NULL"
    add_index :organizations, :billing_status
  end
end
