class CreateBeats < ActiveRecord::Migration[7.1]
  def change
    create_table :beats do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.references :route,        null: true,  foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }

      t.string  :name,   null: false
      t.string  :code,   null: false
      t.boolean :active, null: false, default: true
      t.text    :notes

      t.timestamps
    end

    add_index :beats, [:branch_id, :code],
              unique: true,
              name:   'index_beats_on_branch_id_and_code'
    add_index :beats, [:organization_id, :active],
              name: 'index_beats_on_org_active'
  end
end
