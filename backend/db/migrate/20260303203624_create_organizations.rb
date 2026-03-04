class CreateOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :organizations do |t|
      t.string  :name,    null: false
      t.string  :slug,    null: false
      t.string  :plan,    null: false, default: 'starter'
      t.boolean :active,  null: false, default: true
      t.string  :gst_number
      t.string  :address
      t.string  :city
      t.string  :state
      t.string  :pincode
      t.string  :contact_email
      t.string  :contact_phone

      t.timestamps
    end
    add_index :organizations, :slug, unique: true
  end
end
