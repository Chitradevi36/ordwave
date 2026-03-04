class CreateBranches < ActiveRecord::Migration[7.1]
  def change
    create_table :branches do |t|
      t.string  :name,            null: false
      t.references :organization, null: false, foreign_key: true
      t.string  :code,            null: false
      t.string  :city
      t.string  :state
      t.boolean :active,          null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :branches, :code, unique: true
    add_index :branches, :deleted_at
  end
end
