class CreateVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicles do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :registration_number, null: false
      t.string  :vehicle_type,        null: false, default: 'truck'
      t.decimal :capacity_kg,         precision: 10, scale: 2
      t.integer :capacity_units
      t.bigint  :default_driver_id
      t.date    :insurance_expiry
      t.date    :fitness_expiry
      t.date    :permit_expiry
      t.string  :status, null: false, default: 'active'
      t.text    :notes
      t.datetime :deleted_at

      t.timestamps
    end

    add_foreign_key :vehicles, :users, column: :default_driver_id
    add_index :vehicles, [:organization_id, :registration_number], unique: true, where: 'deleted_at IS NULL'
    add_index :vehicles, :status
    add_index :vehicles, :deleted_at
  end
end
