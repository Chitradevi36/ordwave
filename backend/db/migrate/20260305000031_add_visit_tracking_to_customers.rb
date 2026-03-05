class AddVisitTrackingToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :last_visited_at, :datetime
    add_column :customers, :next_due_on,     :date

    add_index :customers, :next_due_on, name: 'index_customers_on_next_due_on'
    add_index :customers, :last_visited_at, name: 'index_customers_on_last_visited_at'
  end
end
