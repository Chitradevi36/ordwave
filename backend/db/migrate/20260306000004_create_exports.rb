class CreateExports < ActiveRecord::Migration[7.1]
  def change
    create_table :exports do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string     :export_type,  null: false   # orders | invoices | payments | customers | inventory
      t.string     :status,       null: false, default: "pending"   # pending | processing | ready | failed
      t.string     :format,       null: false, default: "csv"       # csv | xlsx
      t.jsonb      :filters,      null: false, default: {}
      t.text       :error_message
      t.integer    :row_count
      t.datetime   :completed_at
      t.timestamps
    end

    add_index :exports, [:organization_id, :status, :created_at],
              name: "idx_exports_org_status_created"
    add_index :exports, [:requested_by_id, :created_at],
              name: "idx_exports_user_created"
  end
end
