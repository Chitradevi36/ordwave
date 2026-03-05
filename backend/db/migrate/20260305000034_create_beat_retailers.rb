class CreateBeatRetailers < ActiveRecord::Migration[7.1]
  OVERRIDES = %w[default force_include force_exclude].freeze

  def change
    create_table :beat_retailers do |t|
      t.references :beat_schedule, null: false, foreign_key: true
      # customers table = retailers
      t.references :customer,      null: false, foreign_key: true, index: false

      t.integer :sequence_number, null: false, default: 0
      t.string  :visit_override,  null: false, default: 'default'
      t.text    :notes

      t.timestamps
    end

    # A retailer can appear only once per schedule
    add_index :beat_retailers,
              [:beat_schedule_id, :customer_id],
              unique: true,
              name:   'index_beat_retailers_schedule_customer'
  end
end
