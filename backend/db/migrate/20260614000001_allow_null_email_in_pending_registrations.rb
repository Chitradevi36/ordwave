class AllowNullEmailInPendingRegistrations < ActiveRecord::Migration[7.1]
  def change
    change_column_null :pending_registrations, :email, true
  end
end
