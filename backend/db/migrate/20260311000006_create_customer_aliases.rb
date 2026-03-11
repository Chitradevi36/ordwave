# frozen_string_literal: true

class CreateCustomerAliases < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_aliases do |t|
      t.references :customer, null: false, foreign_key: true, index: true
      t.string :alias_name, null: false

      t.timestamps
    end

    add_index :customer_aliases, :alias_name
    # Customer can have multiple aliases; same alias can belong to only one customer per org
    # Enforced at service level with uniqueness scoped to organization
  end
end
