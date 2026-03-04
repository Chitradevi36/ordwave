class AddEnhancedFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :customer_type,     :string,  default: 'retailer'
    add_column :customers, :visit_frequency,   :string
    add_column :customers, :credit_days,       :integer, default: 30
    add_column :customers, :credit_block_rule, :string,  default: 'none'
    add_column :customers, :opening_balance,   :decimal, precision: 12, scale: 2, default: '0.0'
    add_column :customers, :tag_list,          :text,    array: true, default: []
    add_reference :customers, :sales_rep, foreign_key: { to_table: :users }, null: true

    add_index :customers, :customer_type
    add_index :customers, :tag_list, using: :gin
  end
end
