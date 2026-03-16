# frozen_string_literal: true

class AddDunningConfigToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :dunning_config, :jsonb, null: false, default: {
      "enabled": false,
      "day_1": { "type": "friendly_reminder", "enabled": true },
      "day_5": { "type": "urgent_notice", "enabled": true },
      "day_10": { "type": "final_notice", "action": "suspend_account", "enabled": true },
      "max_reminders_per_month": 3,
      "quiet_hours_start": 22,
      "quiet_hours_end": 8
    }

    add_column :sales_invoices, :dunning_attempts, :jsonb, null: false, default: []

    # Index for querying overdue invoices for dunning
    add_index :sales_invoices, [:organization_id, :due_date, :status],
              name: 'idx_sales_invoices_dunning_query'
  end
end
