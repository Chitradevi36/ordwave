class AddDunningSuspensionToCustomers < ActiveRecord::Migration[7.1]
  def change
    # Track dunning-based account suspensions separately from manual blocks
    add_column :customers, :dunning_suspended_at, :datetime, comment: 'When customer account was suspended due to dunning'
    add_column :customers, :dunning_suspension_reason, :string, comment: 'Which dunning step triggered suspension (day_10)'
    add_column :customers, :dunning_suspension_invoice_id, :bigint, comment: 'Which invoice triggered the suspension'
    
    add_index :customers, :dunning_suspended_at, where: "dunning_suspended_at IS NOT NULL"
  end
end
