class CreateBillingEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :subscription,              foreign_key: true   # nullable — some events have no subscription yet
      t.string     :event_type,   null: false
      t.string     :razorpay_event_id            # nil for synthetic/internal events
      t.jsonb      :payload,      default: {}, null: false
      t.datetime   :processed_at
      t.text       :error_message

      t.timestamps null: false
    end

    add_index :billing_events, :razorpay_event_id, unique: true,
              where: "razorpay_event_id IS NOT NULL"
    add_index :billing_events, :event_type
    add_index :billing_events, :processed_at
    add_index :billing_events, [ :organization_id, :event_type ]
  end
end
