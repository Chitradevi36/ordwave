class CreateSMSLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :sms_logs do |t|
      t.string :phone_number, null: false
      t.text :message_body, null: false
      t.string :message_type, null: true
      t.string :twilio_sid, null: false, index: { unique: true }
      t.jsonb :metadata, default: {}
      t.datetime :sent_at, null: true

      t.timestamps
    end

    add_index :sms_logs, :phone_number
    add_index :sms_logs, :message_type
    add_index :sms_logs, :created_at
  end
end
