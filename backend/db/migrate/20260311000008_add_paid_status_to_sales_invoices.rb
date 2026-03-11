# frozen_string_literal: true
#
# The existing STATUSES list on SalesInvoice uses 'issued' for open invoices and
# 'partially_paid' for partially settled ones.  We add 'paid' so the reconciliation
# posting service can mark invoices as fully settled without ambiguity.
#
# After applying this migration, update SalesInvoice::STATUSES in the model to
# include 'paid'.  Existing data is unaffected — no backfill needed.

class AddPaidStatusToSalesInvoices < ActiveRecord::Migration[7.1]
  # This is a no-op DDL migration — PostgreSQL stores status as a plain varchar.
  # The change is purely in the application-layer STATUSES constant (see model).
  # Kept here to record the intent in the migration history.
  def change
    # No schema change needed — varchar 'status' already accepts any string value.
    # The model constant SalesInvoice::STATUSES is updated separately.
  end
end
