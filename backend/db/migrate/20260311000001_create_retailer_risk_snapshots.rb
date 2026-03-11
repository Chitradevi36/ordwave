class CreateRetailerRiskSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :retailer_risk_snapshots do |t|
      t.bigint  :organization_id, null: false
      t.bigint  :customer_id,     null: false
      t.integer :risk_score,      null: false, default: 0      # 0–100
      t.string  :risk_tier,       null: false, default: 'low'  # low|medium|high|critical
      t.string  :recommendation,  null: false                  # human-readable action
      t.jsonb   :factors_json,    null: false, default: {}     # scored factor breakdown
      t.string  :score_version,   null: false, default: 'v1'   # scoring model version tag
      t.datetime :computed_at,    null: false
      t.timestamps
    end

    # One active snapshot per customer (latest wins); keep history via created_at
    add_index :retailer_risk_snapshots, :organization_id
    add_index :retailer_risk_snapshots, %i[customer_id computed_at], name: 'idx_risk_snapshots_customer_time'
    add_index :retailer_risk_snapshots, :risk_tier
    add_index :retailer_risk_snapshots, :risk_score
    add_index :retailer_risk_snapshots, %i[organization_id risk_tier], name: 'idx_risk_snapshots_org_tier'

    add_foreign_key :retailer_risk_snapshots, :organizations
    add_foreign_key :retailer_risk_snapshots, :customers
  end
end
