# frozen_string_literal: true

class AddBudgetToSchemes < ActiveRecord::Migration[7.1]
  def change
    add_column :schemes, :budget_amount, :decimal, precision: 14, scale: 2
    add_column :schemes, :utilized_amount, :decimal, precision: 14, scale: 2, default: 0.0, null: false
    add_column :schemes, :budget_alert_pct, :integer, default: 80 # alert when utilization exceeds this %
  end
end
