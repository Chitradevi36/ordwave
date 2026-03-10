class CreateCollectionSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :collection_schedules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :customer,     null: false, foreign_key: true
      t.references :assigned_to,  null: false, foreign_key: { to_table: :users }

      t.date    :scheduled_date,  null: false
      t.decimal :amount_expected, precision: 12, scale: 2, null: false, default: 0
      t.string  :status,          null: false, default: "planned"
      t.text    :notes

      # On completion
      t.references :completed_payment, foreign_key: { to_table: :payments }

      # On reschedule
      t.date   :rescheduled_to

      # On skip
      t.string :skip_reason

      t.timestamps
    end

    # Query indexes
    add_index :collection_schedules, [:assigned_to_id, :scheduled_date, :status],
              name: "idx_collection_schedules_assigned_date_status"
    add_index :collection_schedules, [:organization_id, :branch_id, :scheduled_date],
              name: "idx_collection_schedules_org_branch_date"
    add_index :collection_schedules, [:customer_id, :scheduled_date],
              name: "idx_collection_schedules_customer_date"
  end
end
