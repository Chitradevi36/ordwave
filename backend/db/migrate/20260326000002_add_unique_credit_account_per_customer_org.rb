# frozen_string_literal: true

# Tier 2 #20 — Add unique constraint on credit_accounts(customer_id, organization_id).
#
# Business rule: a customer may only have ONE credit account per organization.
# The partial index `idx_credit_accounts_overdue` already exists but is not a
# uniqueness constraint — it only covers rows where current_balance > 0.
class AddUniqueCreditAccountPerCustomerOrg < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!  # allow CREATE INDEX CONCURRENTLY

  def change
    add_index :credit_accounts, %i[customer_id organization_id],
              unique: true,
              name:   "idx_credit_accounts_customer_org_unique",
              algorithm: :concurrently
  end
end
