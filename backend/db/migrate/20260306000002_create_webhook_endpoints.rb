class CreateWebhookEndpoints < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_endpoints do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.string     :url,          null: false
      t.string     :secret,       null: false          # HMAC-SHA256 signing key
      t.string     :description
      t.jsonb      :events,       null: false, default: []   # array of event names to receive
      t.boolean    :active,       null: false, default: true
      t.integer    :failure_count,null: false, default: 0
      t.datetime   :last_success_at
      t.datetime   :last_failure_at
      t.string     :last_failure_reason
      t.timestamps
    end

    add_index :webhook_endpoints, [:organization_id, :active],
              name: "idx_webhook_endpoints_org_active"

    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true, index: true
      t.references :organization,     null: false, foreign_key: true, index: true
      t.string     :event,            null: false
      t.string     :status,           null: false, default: "pending"   # pending | delivered | failed
      t.jsonb      :payload,          null: false, default: {}
      t.integer    :response_code
      t.text       :response_body
      t.integer    :attempt_count,    null: false, default: 0
      t.datetime   :delivered_at
      t.timestamps
    end

    add_index :webhook_deliveries, [:webhook_endpoint_id, :event, :created_at],
              name: "idx_webhook_deliveries_endpoint_event"
    add_index :webhook_deliveries, [:organization_id, :status, :created_at],
              name: "idx_webhook_deliveries_org_status"
  end
end
