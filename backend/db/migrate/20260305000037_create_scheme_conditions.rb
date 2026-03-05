class CreateSchemeConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :scheme_conditions do |t|
      t.references :scheme, null: false, foreign_key: true
      t.string  :condition_type, null: false
      # min_order_value | min_total_qty | product_inclusion | product_exclusion
      # category_inclusion | brand_inclusion | retailer_inclusion | retailer_exclusion
      t.string  :operator,       null: false, default: '>='
      # >=  >  =  in
      t.jsonb   :value,          null: false, default: {}
      # Examples:
      #   min_order_value  : { amount: 1000 }
      #   min_total_qty    : { qty: 10 }
      #   product_inclusion: { product_ids: [1,2,3] }
      #   category_inclusion:{ category_ids: [5] }
      #   retailer_inclusion:{ customer_ids: [10,11] }

      t.timestamps
    end

    add_index :scheme_conditions, :condition_type
  end
end
