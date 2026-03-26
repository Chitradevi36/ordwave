# frozen_string_literal: true

class AddNotNullToSalesOrdersTotalAmount < ActiveRecord::Migration[7.1]
  def up
    # Backfill any existing NULLs to 0.0 (matches column default)
    execute <<~SQL
      UPDATE sales_orders SET total_amount = 0.0 WHERE total_amount IS NULL;
    SQL

    change_column_null :sales_orders, :total_amount, false
  end

  def down
    change_column_null :sales_orders, :total_amount, true
  end
end
