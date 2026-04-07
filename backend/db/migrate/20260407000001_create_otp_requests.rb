class CreateOtpRequests < ActiveRecord::Migration[7.1]
  def change    
    create_table :otp_requests do |t|
      t.references :user, foreign_key: true, null: true
      t.string    :request_id,       null: false, index: { unique: true }
      t.string    :identifier,       null: false, comment: 'Email or phone number being verified'
      t.integer   :identifier_type,  null: false, default: 0, comment: '0=email, 1=phone'
      t.string    :otp_code,         null: false
      t.integer   :otp_attempts,     null: false, default: 0
      t.datetime  :otp_sent_at
      t.boolean   :verified,         null: false, default: false
      t.datetime  :verified_at
      t.datetime  :expires_at

      t.timestamps
    end

    # Index for cleanup queries
    add_index :otp_requests, :identifier_type
    add_index :otp_requests, [:identifier, :identifier_type]
  end
end
