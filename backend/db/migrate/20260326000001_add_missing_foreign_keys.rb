# frozen_string_literal: true

# Tier 2 #19 — Add 5 missing foreign keys identified in audit.
#
# Missing FKs:
#   1. sales_order_lines.price_list_id   → price_lists
#   2. inventory_reservations.sales_order_line_id → sales_order_lines
#   3. delivery_rejections.return_request_id → return_requests
#   4. stock_movements.created_by_id     → users
#   5. stock_movements.reference_line_id → sales_order_lines
#
# All columns are nullable, so we use `validate: false` for safety on large
# tables and then validate in a follow-up step within the same migration.
class AddMissingForeignKeys < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :sales_order_lines, :price_lists,
                    column: :price_list_id, validate: false

    add_foreign_key :inventory_reservations, :sales_order_lines,
                    column: :sales_order_line_id, validate: false

    add_foreign_key :delivery_rejections, :return_requests,
                    column: :return_request_id, validate: false

    add_foreign_key :stock_movements, :users,
                    column: :created_by_id, validate: false

    add_foreign_key :stock_movements, :sales_order_lines,
                    column: :reference_line_id, validate: false

    # Now validate all five in a second pass (non-blocking on PG 12+)
    validate_foreign_key :sales_order_lines, :price_lists
    validate_foreign_key :inventory_reservations, :sales_order_lines
    validate_foreign_key :delivery_rejections, :return_requests
    validate_foreign_key :stock_movements, :users, column: :created_by_id
    validate_foreign_key :stock_movements, :sales_order_lines, column: :reference_line_id
  end
end
