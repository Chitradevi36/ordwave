# frozen_string_literal: true

# Data migration: ensures all system roles exist.
# Safe to re-run (find_or_create_by! is idempotent).
# Removes the dependency on `db:seed` for roles to be present on first boot.
class SeedDefaultRoles < ActiveRecord::Migration[7.1]
  ROLE_DEFINITIONS = [
    { name: 'owner',           description: 'Organization owner — full access, billing control' },
    { name: 'admin',           description: 'Administrator — full operational access within org' },
    { name: 'manager',         description: 'Branch manager — manage staff, inventory, orders' },
    { name: 'sales_rep',       description: 'Sales representative — create and manage orders' },
    { name: 'warehouse_staff', description: 'Warehouse staff — manage inventory and dispatch' },
    { name: 'accountant',      description: 'Accountant — view financials, manage payments' },
    { name: 'driver',          description: 'Delivery driver — complete trip stops via mobile app' },
  ].freeze

  def up
    ROLE_DEFINITIONS.each do |attrs|
      execute <<~SQL
        INSERT INTO roles (name, description, created_at, updated_at)
        VALUES (#{quote(attrs[:name])}, #{quote(attrs[:description])}, NOW(), NOW())
        ON CONFLICT (name) DO NOTHING;
      SQL
    end
  end

  def down
    # Roles are referenced by memberships — do not remove in a rollback
    # to avoid FK violations in existing environments.
  end

  private

  def quote(str)
    ActiveRecord::Base.connection.quote(str)
  end
end
