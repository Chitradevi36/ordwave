class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :actor,        null: false, foreign_key: { to_table: :users }, index: true
      t.string     :auditable_type, null: false
      t.bigint     :auditable_id,   null: false
      t.string     :action,         null: false        # e.g. "credit_limit_changed", "flag_changed"
      t.jsonb      :changes_data,   null: false, default: {}
      t.string     :reason
      t.datetime   :created_at,     null: false

      t.index [:auditable_type, :auditable_id], name: "index_audit_logs_on_auditable"
    end
  end
end
