class CreateRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :routes do |t|
      t.string  :name,            null: false
      t.string  :code,            null: false
      t.references :branch,       null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.boolean :active,          default: true, null: false

      t.timestamps
    end

    add_index :routes, %i[branch_id code], unique: true
  end
end
