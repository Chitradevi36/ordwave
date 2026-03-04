class AddSettingsToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :settings, :jsonb, null: false, default: {}

    add_index :branches, :settings, using: :gin
  end
end
