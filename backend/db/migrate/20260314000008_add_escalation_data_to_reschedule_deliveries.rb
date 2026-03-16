class AddEscalationDataToRescheduleDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_column :reschedule_deliveries, :escalation_data, :jsonb, null: false, default: {}
    
    # Track escalation state: when notified, when refund initiated, etc.
    # {
    #   "last_notification_sent_at": "2026-03-14",
    #   "refund_initiated_at": "2026-03-21T10:30:00Z",
    #   "refund_reason": "Auto-refund after 7 days",
    #   "auto_refund_failed": "Payment not found"
    # }
  end
end
