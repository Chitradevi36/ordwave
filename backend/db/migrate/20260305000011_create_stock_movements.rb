class CreateStockMovements < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_movements do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :product,      null: false, foreign_key: true
      t.string  :movement_type,   null: false  # purchase / sale / adjustment / return / reversal
      t.string  :direction,       null: false, default: 'in'  # in / out
      t.decimal :qty,             precision: 14, scale: 3, null: false
      t.decimal :unit_cost,       precision: 14, scale: 2   # cost at time of movement
      t.string  :reference_type   # PurchaseInvoice | SalesOrder | etc (polymorphic)
      t.bigint  :reference_id
      t.bigint  :created_by_id
      t.text    :notes
      t.timestamps
    end

    add_index :stock_movements, %i[reference_type reference_id], name: 'index_stock_movements_on_reference'
    add_index :stock_movements, :movement_type
    add_index :stock_movements, :created_at
  end
end
