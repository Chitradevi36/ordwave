class AddSchemeFieldsToOrderLines < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_order_lines, :scheme_discount_pct, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :sales_order_lines, :scheme_tags,         :jsonb,   default: []
    # scheme_tags: [{scheme_id, scheme_code, scheme_name, reward_type, discount_applied}]
  end
end
