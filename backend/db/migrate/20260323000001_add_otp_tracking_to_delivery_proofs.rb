class AddOtpTrackingToDeliveryProofs < ActiveRecord::Migration[7.1]
  def change
    add_column :delivery_proofs, :otp_sent_at, :datetime
    add_column :delivery_proofs, :otp_attempts, :integer, default: 0
    add_column :delivery_proofs, :otp_proof_type, :string

    add_index :delivery_proofs, :otp_sent_at
  end
end
