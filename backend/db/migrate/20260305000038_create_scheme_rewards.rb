class CreateSchemeRewards < ActiveRecord::Migration[7.1]
  def change
    create_table :scheme_rewards do |t|
      t.references :scheme, null: false, foreign_key: true
      t.string  :reward_type,     null: false
      # percent_off | amount_off | free_qty | fixed_price
      t.string  :target_scope,    null: false, default: 'order'
      # order | line | product
      t.references  :target_product, foreign_key: { to_table: :products }              # required for free_qty / fixed_price / product scope

      t.decimal :reward_value,    precision: 14, scale: 4, null: false
      t.decimal :max_reward_value, precision: 14, scale: 2  # cap for amount_off on order
      t.integer :free_per_x                     # for buy X get Y: trigger quantity X
      t.integer :free_qty_per_trigger           # how many free per trigger

      t.timestamps
    end
  end
end
