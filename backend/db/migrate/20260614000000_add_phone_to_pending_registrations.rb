class AddPhoneToPendingRegistrations < ActiveRecord::Migration[7.1]
  def change
    add_column :pending_registrations, :phone, :string
    add_index :pending_registrations, :phone, unique: true
  end
end
