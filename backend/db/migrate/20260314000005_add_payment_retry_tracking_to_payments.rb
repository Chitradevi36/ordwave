class AddPaymentRetryTrackingToPayments < ActiveRecord::Migration[7.1]
  def change
    # Add retry tracking fields to payments table
    add_column :payments, :failed_reason, :string, comment: 'Reason for payment failure (e.g., "insufficient_funds", "card_declined", "network_error")'
    add_column :payments, :retry_count, :integer, default: 0, comment: 'Number of retry attempts made'
    add_column :payments, :next_retry_at, :datetime, comment: 'Timestamp of scheduled next retry'
    add_column :payments, :last_retry_at, :datetime, comment: 'Timestamp of last retry attempt'
    add_column :payments, :retry_status, :string, default: 'pending', comment: 'pending | scheduled | completed | abandoned'
    
    # Add index for retry scheduling queries
    add_index :payments, %i[retry_status next_retry_at], where: "retry_status IN ('pending', 'scheduled')", name: 'idx_payments_retry_scheduling'
    add_index :payments, %i[external_payment_status retry_count], where: "external_payment_status = 'failed'", name: 'idx_payments_failed_retryable'
  end
end
