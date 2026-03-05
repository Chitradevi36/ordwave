class CreateReturnQcItems < ActiveRecord::Migration[7.1]
  def change
    create_table :return_qc_items do |t|
      t.references :return_line, null: false, foreign_key: true
      t.references :qc_by,       null: false, foreign_key: { to_table: :users }

      t.decimal :qty_resalable, precision: 14, scale: 3, null: false, default: 0
      t.decimal :qty_damaged,   precision: 14, scale: 3, null: false, default: 0
      t.decimal :qty_expired,   precision: 14, scale: 3, null: false, default: 0

      # condition_final summarises the dominant outcome for reporting
      t.string  :condition_final, null: false, default: 'resalable'
      # resalable | damaged | expired | mixed

      t.text     :qc_notes
      t.datetime :qc_at, null: false

      t.timestamps
    end
    # One QC record per line (one-to-one)
  end
end
