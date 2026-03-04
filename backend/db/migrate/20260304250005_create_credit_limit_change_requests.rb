class CreateCreditLimitChangeRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_limit_change_requests do |t|
      t.references :credit_account, null: false, foreign_key: true, index: true
      t.references :requested_by,   null: false, foreign_key: { to_table: :users }, index: true
      t.references :decided_by,     null: true,  foreign_key: { to_table: :users }, index: true
      t.decimal    :new_limit,         precision: 12, scale: 2, null: false
      t.decimal    :counter_offer_limit, precision: 12, scale: 2
      t.string     :status,            default: "pending", null: false
      t.text       :reason,            null: false
      t.text       :supporting_notes
      t.text       :decision_note
      t.datetime   :decided_at
      t.datetime   :sla_breached_at

      t.timestamps

      t.index [:status], name: "index_credit_limit_change_requests_on_status"
      t.index [:credit_account_id, :status], name: "idx_clcr_account_status"
    end
  end
end
