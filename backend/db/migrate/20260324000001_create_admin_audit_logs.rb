class CreateAdminAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_audit_logs do |t|
      # Relationships
      t.references :organization, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, null: true, foreign_key: { to_table: :users }

      # Action details
      t.string :action_type, null: false, index: true
      t.string :resource_type, null: false, index: true
      t.bigint :resource_id, null: true
      t.string :resource_name, null: true

      # Changes tracking
      t.jsonb :changes, default: {}, null: false
      t.jsonb :before_values, default: {}, null: false
      t.jsonb :after_values, default: {}, null: false

      # Context
      t.string :reason
      t.string :ip_address
      t.string :user_agent
      t.string :session_id

      # Status & approval
      t.string :status, null: false, default: 'completed'
      t.datetime :approved_at
      t.string :approval_reason

      t.timestamps

      # Performance indexes
      t.index [:organization_id, :created_at]
      t.index [:admin_user_id, :created_at]
      t.index [:resource_type, :action_type]
      t.index [:status, :created_at]
    end
  end
end
