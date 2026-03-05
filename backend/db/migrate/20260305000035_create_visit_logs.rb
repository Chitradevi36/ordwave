class CreateVisitLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :visit_logs do |t|
      t.references :organization,    null: false, foreign_key: true
      t.references :branch,          null: false, foreign_key: true
      t.references :sales_rep,       null: false, foreign_key: { to_table: :users }, index: false
      t.references :customer,        null: false, foreign_key: true, index: false
      t.references :route,           null: true,  foreign_key: true
      t.references :beat_schedule,   null: true,  foreign_key: true

      t.date     :visit_date,   null: false
      t.datetime :checkin_at
      t.datetime :checkout_at
      t.decimal  :gps_lat,      precision: 10, scale: 6
      t.decimal  :gps_lng,      precision: 10, scale: 6
      t.text     :notes
      t.string   :visit_status, null: false, default: 'planned'
        # planned | checked_in | completed | skipped
      t.string   :skip_reason_code
      t.string   :device_id
      t.string   :idempotency_key

      t.timestamps
    end

    add_index :visit_logs, :idempotency_key,
              unique: true,
              where:  'idempotency_key IS NOT NULL',
              name:   'index_visit_logs_on_idempotency_key'

    add_index :visit_logs, [:sales_rep_id, :visit_date],
              name: 'index_visit_logs_rep_date'
    add_index :visit_logs, [:customer_id, :visit_date],
              name: 'index_visit_logs_customer_date'
    add_index :visit_logs, :visit_status,
              name: 'index_visit_logs_on_status'
    add_index :visit_logs, :visit_date,
              name: 'index_visit_logs_on_visit_date'
  end
end
