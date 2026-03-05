class CreateBeatSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :beat_schedules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :beat,         null: false, foreign_key: true
      t.references :sales_rep,    null: false, foreign_key: { to_table: :users }

      # 0 = Monday … 6 = Sunday  (ISO-aligned)
      t.integer :weekday,    null: false
      t.time    :start_time
      t.time    :end_time
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # One rep should not have two active schedules on the same weekday in the same branch
    add_index :beat_schedules,
              [:branch_id, :sales_rep_id, :weekday],
              name: 'index_beat_schedules_rep_weekday'

    add_index :beat_schedules, [:beat_id, :weekday],
              name: 'index_beat_schedules_beat_weekday'
  end
end
