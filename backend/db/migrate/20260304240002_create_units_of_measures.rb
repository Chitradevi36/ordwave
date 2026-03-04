class CreateUnitsOfMeasures < ActiveRecord::Migration[7.1]
  def change
    create_table :units_of_measures do |t|
      t.string  :name,   null: false
      t.string  :symbol, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :units_of_measures, :name,   unique: true
    add_index :units_of_measures, :symbol, unique: true
  end
end
