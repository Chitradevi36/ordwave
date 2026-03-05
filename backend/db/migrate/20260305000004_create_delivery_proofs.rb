class CreateDeliveryProofs < ActiveRecord::Migration[7.1]
  def change
    create_table :delivery_proofs do |t|
      t.references :trip_stop, null: false, foreign_key: true
      t.string  :proof_type,     null: false, default: 'photo' # photo | signature | otp | override
      t.string  :otp_code_digest
      t.datetime :otp_verified_at
      t.string  :override_reason
      t.bigint  :overridden_by_id

      t.timestamps
    end

    add_foreign_key :delivery_proofs, :users, column: :overridden_by_id
    add_index :delivery_proofs, :proof_type
  end
end
