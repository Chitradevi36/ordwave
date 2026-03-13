class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :organization, null: false, foreign_key: true
      t.string     :plan,                         null: false
      t.string     :status,    default: "pending", null: false
      t.string     :razorpay_subscription_id
      t.string     :razorpay_plan_id
      t.integer    :quantity,  default: 1,         null: false
      t.datetime   :current_period_start
      t.datetime   :current_period_end
      t.datetime   :trial_ends_at
      t.datetime   :cancelled_at
      t.datetime   :ends_at
      t.jsonb      :metadata,  default: {},        null: false

      t.timestamps null: false
    end

    add_index :subscriptions, :razorpay_subscription_id, unique: true,
              where: "razorpay_subscription_id IS NOT NULL"
    add_index :subscriptions, :status
    add_index :subscriptions, :plan
    add_index :subscriptions, [ :organization_id, :status ]
  end
end
