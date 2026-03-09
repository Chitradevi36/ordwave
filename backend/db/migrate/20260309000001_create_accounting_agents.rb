# frozen_string_literal: true

class CreateAccountingAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_agents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :accounting_integration, null: false, foreign_key: true
      t.string :agent_id, null: false
      t.string :api_key_digest, null: false
      t.string :agent_version
      t.string :os_info
      t.string :tally_version
      t.datetime :last_heartbeat_at
      t.datetime :registered_at
      t.string :status, default: "offline", null: false

      t.timestamps
    end

    add_index :accounting_agents, :agent_id, unique: true
    add_index :accounting_agents, :status
    add_index :accounting_agents, :last_heartbeat_at
  end
end
