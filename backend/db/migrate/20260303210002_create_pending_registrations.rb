class CreatePendingRegistrations < ActiveRecord::Migration[7.1]
  def change
    create_table :pending_registrations do |t|
      t.string   :email,         null: false
      t.string   :otp_code
      t.datetime :otp_sent_at
      t.integer  :otp_attempts,  default: 0, null: false
      t.string   :current_step,  default: 'initiate', null: false
      t.jsonb    :data,          default: {}, null: false
      t.datetime :expires_at
      t.boolean  :completed,     default: false, null: false

      t.timestamps
    end

    add_index :pending_registrations, :email, unique: true
    add_index :pending_registrations, :otp_code
    add_index :pending_registrations, :expires_at
  end
end
