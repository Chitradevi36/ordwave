class AddCriticalDbConstraints < ActiveRecord::Migration[7.1]
  def up
    # ── CHECK constraints ──────────────────────────────────────────────────────
    execute <<~SQL
      ALTER TABLE inventory_levels
        ADD CONSTRAINT chk_inventory_levels_qty_on_hand_non_negative
          CHECK (qty_on_hand >= 0),
        ADD CONSTRAINT chk_inventory_levels_qty_reserved_non_negative
          CHECK (qty_reserved >= 0);
    SQL

    execute <<~SQL
      ALTER TABLE credit_accounts
        ADD CONSTRAINT chk_credit_accounts_credit_limit_non_negative
          CHECK (credit_limit >= 0);
    SQL

    execute <<~SQL
      ALTER TABLE payments
        ADD CONSTRAINT chk_payments_amount_positive
          CHECK (amount > 0);
    SQL

    execute <<~SQL
      ALTER TABLE sales_orders
        ADD CONSTRAINT chk_sales_orders_total_non_negative
          CHECK (total_amount >= 0);
    SQL

    # ── Performance indexes ────────────────────────────────────────────────────
    add_index :sales_orders,     [:branch_id, :created_at],
              name: "idx_sales_orders_branch_created_at",
              if_not_exists: true

    add_index :inventory_levels, [:branch_id, :product_id],
              name: "idx_inventory_levels_branch_product",
              if_not_exists: true

    add_index :payments,         [:customer_id, :received_date],
              name: "idx_payments_customer_payment_date",
              if_not_exists: true

    # ── Partial indexes ────────────────────────────────────────────────────────
    # Active sales orders (draft, submitted, on_hold, approved, dispatched)
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_sales_orders_active_status
        ON sales_orders (organization_id, created_at DESC)
       WHERE status IN ('draft','submitted','on_hold','approved','dispatched');
    SQL

    # Overdue credit accounts (balance > 0)
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_credit_accounts_overdue
        ON credit_accounts (organization_id, customer_id)
       WHERE current_balance > 0;
    SQL

    # ── Audit log indexes (polymorphic lookup performance) ─────────────────────
    add_index :audit_logs, [:auditable_type, :auditable_id, :created_at],
              name: "idx_audit_logs_auditable_created_at",
              if_not_exists: true

    add_index :audit_logs, [:organization_id, :created_at],
              name: "idx_audit_logs_org_created_at",
              if_not_exists: true
  end

  def down
    remove_index :audit_logs, name: "idx_audit_logs_org_created_at",
                 if_exists: true
    remove_index :audit_logs, name: "idx_audit_logs_auditable_created_at",
                 if_exists: true

    execute "DROP INDEX IF EXISTS idx_credit_accounts_overdue;"
    execute "DROP INDEX IF EXISTS idx_sales_orders_active_status;"

    remove_index :payments,         name: "idx_payments_customer_payment_date",
                 if_exists: true
    remove_index :inventory_levels, name: "idx_inventory_levels_branch_product",
                 if_exists: true
    remove_index :sales_orders,     name: "idx_sales_orders_branch_created_at",
                 if_exists: true

    execute <<~SQL
      ALTER TABLE sales_orders
        DROP CONSTRAINT IF EXISTS chk_sales_orders_total_non_negative;
    SQL
    execute <<~SQL
      ALTER TABLE payments
        DROP CONSTRAINT IF EXISTS chk_payments_amount_positive;
    SQL
    execute <<~SQL
      ALTER TABLE credit_accounts
        DROP CONSTRAINT IF EXISTS chk_credit_accounts_credit_limit_non_negative;
    SQL
    execute <<~SQL
      ALTER TABLE inventory_levels
        DROP CONSTRAINT IF EXISTS chk_inventory_levels_qty_reserved_non_negative,
        DROP CONSTRAINT IF EXISTS chk_inventory_levels_qty_on_hand_non_negative;
    SQL
  end
end
