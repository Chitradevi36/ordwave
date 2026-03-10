class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true          # recipient
      t.references :actor,        foreign_key: { to_table: :users },      # who triggered it
                                  null: true
      t.string  :notifiable_type                                           # polymorphic
      t.bigint  :notifiable_id
      t.string  :notification_type, null: false
      t.string  :title,             null: false
      t.text    :body
      t.string  :deep_link_url
      t.string  :severity, default: 'medium', null: false                 # low, medium, high
      t.datetime :read_at
      t.datetime :dismissed_at
      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at],
              where: "read_at IS NULL",
              name: 'idx_unread_notifications'

    add_index :notifications, [:user_id, :organization_id, :created_at],
              name: 'idx_notifications_user_org_created'

    add_index :notifications, [:notifiable_type, :notifiable_id],
              name: 'idx_notifications_notifiable'
  end
end
