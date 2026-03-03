class CreateBranches < ActiveRecord::Migration[7.1]
  def change
    create_table :branches do |t|
      t.string :name
      t.references :organization, null: false, foreign_key: true
      t.string :code
      t.boolean :active

      t.timestamps
    end
    add_index :branches, :code, unique: true
  end
end
