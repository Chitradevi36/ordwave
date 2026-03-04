class AddSettingsToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :pan,      :string
    add_column :organizations, :logo_url, :string
    add_column :organizations, :timezone, :string, default: 'Asia/Kolkata'
    add_column :organizations, :currency, :string, default: 'INR'
    add_column :organizations, :settings, :jsonb,  null: false, default: {}

    add_index :organizations, :settings, using: :gin
  end
end
