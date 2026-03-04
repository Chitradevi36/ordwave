class CreateCreditPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_policies do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }

      # Hard block thresholds
      t.integer  :hard_block_overdue_days,    default: 30,    null: false
      t.decimal  :hard_block_margin_pct,      precision: 6, scale: 2, default: "20.0",  null: false

      # Soft hold thresholds
      t.integer  :soft_hold_overdue_days_min, default: 15,    null: false
      t.integer  :soft_hold_overdue_days_max, default: 29,    null: false
      t.decimal  :soft_hold_outstanding_pct,  precision: 6, scale: 2, default: "100.0", null: false

      # Buckets / labels
      t.string   :collection_first_bucket,    default: "serious", null: false

      # SLA hours
      t.integer  :approval_sla_hours_manager, default: 4, null: false
      t.integer  :approval_sla_hours_owner,   default: 8, null: false

      # Automation
      t.string   :auto_invoice_trigger,       default: "on_delivery", null: false
      t.boolean  :allow_partial_allocation,   default: true,          null: false

      t.timestamps
    end
  end
end
