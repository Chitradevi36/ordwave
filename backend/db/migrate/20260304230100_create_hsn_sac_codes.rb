class CreateHsnSacCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :hsn_sac_codes do |t|
      t.string  :code,           null: false
      t.string  :code_type,      null: false, default: 'HSN'   # HSN | SAC
      t.string  :description
      t.string  :chapter
      t.decimal :gst_rate,       precision: 5, scale: 2, null: false, default: 0
      t.decimal :cgst_rate,      precision: 5, scale: 2, null: false, default: 0
      t.decimal :sgst_rate,      precision: 5, scale: 2, null: false, default: 0
      t.decimal :igst_rate,      precision: 5, scale: 2, null: false, default: 0
      t.boolean :active,         null: false, default: true
      t.date    :effective_from, null: false
      t.date    :effective_to

      t.timestamps
    end

    # Lookup: code + effective window
    add_index :hsn_sac_codes, %i[code effective_from],
              name: 'idx_hsn_sac_codes_on_code_effective_from'

    # Fast lookup of currently-active rate per code (no end date = still valid)
    add_index :hsn_sac_codes, :code,
              where: 'active = true AND effective_to IS NULL',
              name:  'idx_hsn_sac_codes_current_active'

    # Search by type
    add_index :hsn_sac_codes, :code_type,
              name: 'index_hsn_sac_codes_on_code_type'

    add_index :hsn_sac_codes, :gst_rate,
              name: 'index_hsn_sac_codes_on_gst_rate'
  end
end
