# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_04_07_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "accounting_agents", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "accounting_integration_id", null: false
    t.string "agent_id", null: false
    t.string "api_key_digest", null: false
    t.string "agent_version"
    t.string "os_info"
    t.string "tally_version"
    t.datetime "last_heartbeat_at"
    t.datetime "registered_at"
    t.string "status", default: "offline", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_integration_id"], name: "index_accounting_agents_on_accounting_integration_id"
    t.index ["agent_id"], name: "index_accounting_agents_on_agent_id", unique: true
    t.index ["last_heartbeat_at"], name: "index_accounting_agents_on_last_heartbeat_at"
    t.index ["organization_id"], name: "index_accounting_agents_on_organization_id"
    t.index ["status"], name: "index_accounting_agents_on_status"
  end

  create_table "accounting_export_files", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "accounting_integration_id", null: false
    t.string "provider", null: false
    t.string "export_type", null: false
    t.date "date_from"
    t.date "date_to"
    t.bigint "branch_id"
    t.jsonb "filters_json", default: {}, null: false
    t.string "file_path"
    t.string "status", default: "generating", null: false
    t.bigint "generated_by_id"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_integration_id"], name: "idx_accounting_export_files_integration"
    t.index ["accounting_integration_id"], name: "index_accounting_export_files_on_accounting_integration_id"
    t.index ["branch_id"], name: "index_accounting_export_files_on_branch_id"
    t.index ["created_at"], name: "idx_accounting_export_files_created_at"
    t.index ["export_type"], name: "idx_accounting_export_files_export_type"
    t.index ["generated_by_id"], name: "index_accounting_export_files_on_generated_by_id"
    t.index ["organization_id", "provider"], name: "idx_accounting_export_files_org_provider"
    t.index ["organization_id", "status"], name: "idx_accounting_export_files_org_status"
    t.index ["organization_id"], name: "index_accounting_export_files_on_organization_id"
  end

  create_table "accounting_integrations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "provider", null: false
    t.string "status", default: "disconnected", null: false
    t.string "sync_mode", default: "batch_export", null: false
    t.jsonb "config_json", default: {}, null: false
    t.datetime "last_synced_at"
    t.datetime "last_error_at"
    t.text "last_error_message"
    t.bigint "connected_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connected_by_id"], name: "index_accounting_integrations_on_connected_by_id"
    t.index ["last_synced_at"], name: "idx_accounting_integrations_last_synced_at"
    t.index ["organization_id", "provider"], name: "idx_accounting_integrations_org_provider_unique", unique: true
    t.index ["organization_id"], name: "index_accounting_integrations_on_organization_id"
    t.index ["status"], name: "idx_accounting_integrations_status"
    t.index ["sync_mode"], name: "idx_accounting_integrations_sync_mode"
  end

  create_table "accounting_mappings", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "accounting_integration_id", null: false
    t.string "mapping_key", null: false
    t.string "mapping_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_integration_id", "mapping_key"], name: "idx_accounting_mappings_integration_key_unique", unique: true
    t.index ["accounting_integration_id"], name: "index_accounting_mappings_on_accounting_integration_id"
    t.index ["organization_id", "mapping_key"], name: "idx_accounting_mappings_org_key"
    t.index ["organization_id"], name: "index_accounting_mappings_on_organization_id"
  end

  create_table "accounting_sync_records", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "accounting_integration_id", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id", null: false
    t.string "entity_version", null: false
    t.string "event_type", null: false
    t.string "provider", null: false
    t.string "direction", default: "outbound", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.string "idempotency_key", null: false
    t.string "external_reference"
    t.jsonb "payload_json", default: {}, null: false
    t.text "response_body"
    t.text "error_message"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "last_attempted_at"
    t.datetime "succeeded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trigger_type", default: "manual"
    t.string "source_type", comment: "Polymorphic type (e.g., SalesOrder, Payment)"
    t.bigint "source_id", comment: "Polymorphic ID"
    t.bigint "export_file_id", comment: "Associated AccountingExportFile"
    t.jsonb "data_types", default: [], comment: "Types of data to sync [invoices, payments, stock_movements]"
    t.datetime "synced_at", comment: "When sync completed successfully"
    t.datetime "failed_at", comment: "When sync failed"
    t.index ["accounting_integration_id", "status"], name: "idx_accounting_sync_records_integration_status"
    t.index ["accounting_integration_id"], name: "index_accounting_sync_records_on_accounting_integration_id"
    t.index ["created_at"], name: "idx_accounting_sync_records_created_at"
    t.index ["entity_type", "entity_id"], name: "idx_accounting_sync_records_entity"
    t.index ["event_type"], name: "idx_accounting_sync_records_event_type"
    t.index ["export_file_id"], name: "index_accounting_sync_records_on_export_file_id"
    t.index ["last_attempted_at"], name: "idx_accounting_sync_records_last_attempted_at"
    t.index ["organization_id", "provider"], name: "idx_accounting_sync_records_org_provider"
    t.index ["organization_id", "status", "trigger_type"], name: "idx_on_organization_id_status_trigger_type_8e35f9cb2b"
    t.index ["organization_id", "status"], name: "idx_accounting_sync_records_org_status"
    t.index ["organization_id"], name: "index_accounting_sync_records_on_organization_id"
    t.index ["priority"], name: "idx_accounting_sync_records_priority"
    t.index ["provider", "idempotency_key"], name: "idx_accounting_sync_records_idempotency_unique", unique: true
    t.index ["source_type", "source_id"], name: "index_accounting_sync_records_on_source_type_and_source_id"
    t.index ["status", "priority", "created_at"], name: "idx_accounting_sync_records_worker_poll"
    t.index ["trigger_type", "status"], name: "idx_sync_records_trigger_status"
    t.index ["trigger_type"], name: "index_accounting_sync_records_on_trigger_type"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_audit_logs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "admin_user_id", null: false
    t.bigint "approved_by_id"
    t.string "action_type", null: false
    t.string "resource_type", null: false
    t.bigint "resource_id"
    t.string "resource_name"
    t.jsonb "changes", default: {}, null: false
    t.jsonb "before_values", default: {}, null: false
    t.jsonb "after_values", default: {}, null: false
    t.string "reason"
    t.string "ip_address"
    t.string "user_agent"
    t.string "session_id"
    t.string "status", default: "completed", null: false
    t.datetime "approved_at"
    t.string "approval_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_admin_audit_logs_on_action_type"
    t.index ["admin_user_id", "created_at"], name: "index_admin_audit_logs_on_admin_user_id_and_created_at"
    t.index ["admin_user_id"], name: "index_admin_audit_logs_on_admin_user_id"
    t.index ["approved_by_id"], name: "index_admin_audit_logs_on_approved_by_id"
    t.index ["organization_id", "created_at"], name: "index_admin_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_admin_audit_logs_on_organization_id"
    t.index ["resource_type", "action_type"], name: "index_admin_audit_logs_on_resource_type_and_action_type"
    t.index ["resource_type"], name: "index_admin_audit_logs_on_resource_type"
    t.index ["status", "created_at"], name: "index_admin_audit_logs_on_status_and_created_at"
  end

  create_table "advance_payments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "source_payment_id", null: false
    t.decimal "original_amount", precision: 14, scale: 2, null: false
    t.decimal "balance", precision: 14, scale: 2, null: false
    t.string "status", default: "unapplied", null: false
    t.datetime "refunded_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_advance_payments_on_branch_id"
    t.index ["customer_id"], name: "index_advance_payments_on_customer_id"
    t.index ["organization_id", "customer_id", "status"], name: "idx_advance_payments_org_cust_status"
    t.index ["organization_id"], name: "index_advance_payments_on_organization_id"
    t.index ["source_payment_id"], name: "index_advance_payments_on_source_payment_id"
    t.index ["status"], name: "idx_advance_payments_status"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "actor_id", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "changes_data", default: {}, null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "idx_audit_logs_auditable_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["organization_id", "created_at"], name: "idx_audit_logs_org_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

  create_table "auto_post_audits", force: :cascade do |t|
    t.bigint "payment_id"
    t.bigint "bank_transaction_id"
    t.jsonb "confidence_breakdown", default: {}, null: false
    t.boolean "auto_posted", default: false
    t.string "action", limit: 50, null: false
    t.bigint "actor_id"
    t.datetime "timestamp", null: false
    t.text "audit_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "idx_auto_post_audits_action"
    t.index ["bank_transaction_id"], name: "idx_auto_post_audits_bank_transaction_id"
    t.index ["payment_id"], name: "idx_auto_post_audits_payment_id"
    t.index ["timestamp"], name: "idx_auto_post_audits_timestamp"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.string "bank_name", null: false
    t.string "account_name", null: false
    t.string "account_number_masked", null: false
    t.string "account_number_full"
    t.string "ifsc"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_bank_accounts_on_branch_id"
    t.index ["organization_id"], name: "index_bank_accounts_on_organization_id"
    t.index ["status"], name: "index_bank_accounts_on_status"
  end

  create_table "bank_statement_imports", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "bank_account_id", null: false
    t.bigint "uploaded_by_id"
    t.string "file_name", null: false
    t.string "source_type", default: "csv", null: false
    t.string "status", default: "uploaded", null: false
    t.integer "rows_count", default: 0, null: false
    t.integer "processed_rows_count", default: 0, null: false
    t.integer "new_rows_count", default: 0, null: false
    t.integer "duplicate_rows_count", default: 0, null: false
    t.integer "failed_rows_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_bank_statement_imports_on_bank_account_id"
    t.index ["organization_id"], name: "index_bank_statement_imports_on_organization_id"
    t.index ["status"], name: "index_bank_statement_imports_on_status"
    t.index ["uploaded_by_id"], name: "index_bank_statement_imports_on_uploaded_by_id"
  end

  create_table "bank_transaction_matches", force: :cascade do |t|
    t.bigint "bank_transaction_id", null: false
    t.bigint "customer_id"
    t.bigint "sales_invoice_id"
    t.decimal "score", precision: 5, scale: 2, null: false
    t.string "rule_code", null: false
    t.jsonb "explanation", default: {}, null: false
    t.boolean "selected", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_transaction_id"], name: "index_bank_transaction_matches_on_bank_transaction_id"
    t.index ["customer_id"], name: "index_bank_transaction_matches_on_customer_id"
    t.index ["rule_code"], name: "index_bank_transaction_matches_on_rule_code"
    t.index ["sales_invoice_id"], name: "index_bank_transaction_matches_on_sales_invoice_id"
    t.index ["selected"], name: "index_bank_transaction_matches_on_selected"
  end

  create_table "bank_transactions", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "bank_account_id", null: false
    t.bigint "bank_statement_import_id"
    t.date "txn_date", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "direction", default: "credit", null: false
    t.string "utr_number"
    t.string "reference_number"
    t.string "payer_name"
    t.text "narration"
    t.text "normalized_narration"
    t.jsonb "raw_row_json", default: {}, null: false
    t.jsonb "match_meta", default: {}, null: false
    t.string "status", default: "unmatched", null: false
    t.decimal "match_score", precision: 5, scale: 2
    t.string "match_rule"
    t.bigint "matched_customer_id"
    t.bigint "matched_invoice_id"
    t.bigint "matched_payment_id"
    t.bigint "reviewed_by_id"
    t.text "review_notes"
    t.datetime "processed_at"
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "customer_name", limit: 255
    t.string "reference", limit: 255
    t.float "matched_confidence"
    t.index ["amount"], name: "index_bank_transactions_on_amount"
    t.index ["bank_account_id"], name: "index_bank_transactions_on_bank_account_id"
    t.index ["bank_statement_import_id"], name: "index_bank_transactions_on_bank_statement_import_id"
    t.index ["idempotency_key"], name: "index_bank_transactions_on_idempotency_key", unique: true
    t.index ["matched_customer_id"], name: "index_bank_transactions_on_matched_customer_id"
    t.index ["matched_invoice_id"], name: "index_bank_transactions_on_matched_invoice_id"
    t.index ["organization_id"], name: "index_bank_transactions_on_organization_id"
    t.index ["status"], name: "index_bank_transactions_on_status"
    t.index ["txn_date"], name: "index_bank_transactions_on_txn_date"
    t.index ["utr_number"], name: "index_bank_transactions_on_utr_number"
  end

  create_table "beat_retailers", force: :cascade do |t|
    t.bigint "beat_schedule_id", null: false
    t.bigint "customer_id", null: false
    t.integer "sequence_number", default: 1, null: false
    t.string "visit_override", default: "default", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["beat_schedule_id", "customer_id"], name: "index_beat_retailers_schedule_customer", unique: true
    t.index ["beat_schedule_id"], name: "index_beat_retailers_on_beat_schedule_id"
  end

  create_table "beat_schedules", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "beat_id", null: false
    t.bigint "sales_rep_id", null: false
    t.integer "weekday", null: false
    t.time "start_time"
    t.time "end_time"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["beat_id", "weekday"], name: "index_beat_schedules_beat_weekday"
    t.index ["beat_id"], name: "index_beat_schedules_on_beat_id"
    t.index ["branch_id", "sales_rep_id", "weekday"], name: "index_beat_schedules_rep_weekday"
    t.index ["branch_id"], name: "index_beat_schedules_on_branch_id"
    t.index ["organization_id"], name: "index_beat_schedules_on_organization_id"
    t.index ["sales_rep_id"], name: "index_beat_schedules_on_sales_rep_id"
  end

  create_table "beats", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "route_id"
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "code"], name: "index_beats_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_beats_on_branch_id"
    t.index ["created_by_id"], name: "index_beats_on_created_by_id"
    t.index ["organization_id", "active"], name: "index_beats_on_org_active"
    t.index ["organization_id"], name: "index_beats_on_organization_id"
    t.index ["route_id"], name: "index_beats_on_route_id"
  end

  create_table "billing_events", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "subscription_id"
    t.string "event_type", null: false
    t.string "razorpay_event_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_billing_events_on_event_type"
    t.index ["organization_id", "event_type"], name: "index_billing_events_on_organization_id_and_event_type"
    t.index ["organization_id"], name: "index_billing_events_on_organization_id"
    t.index ["processed_at"], name: "index_billing_events_on_processed_at"
    t.index ["razorpay_event_id"], name: "index_billing_events_on_razorpay_event_id", unique: true, where: "(razorpay_event_id IS NOT NULL)"
    t.index ["subscription_id"], name: "index_billing_events_on_subscription_id"
  end

  create_table "branches", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "code", null: false
    t.string "city"
    t.string "state"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "pincode"
    t.jsonb "settings", default: {}, null: false
    t.string "state_code", limit: 2
    t.index ["code"], name: "index_branches_on_code", unique: true
    t.index ["deleted_at"], name: "index_branches_on_deleted_at"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
    t.index ["settings"], name: "index_branches_on_settings", using: :gin
    t.index ["state_code"], name: "index_branches_on_state_code"
  end

  create_table "bulk_generations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "session_id", null: false
    t.integer "total_count", default: 0, null: false
    t.integer "completed_count", default: 0, null: false
    t.integer "error_count", default: 0, null: false
    t.string "status", default: "in_progress", null: false
    t.jsonb "errors", default: [], null: false
    t.text "error_message"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "idx_bulk_gen_created_at"
    t.index ["organization_id", "completed_at"], name: "idx_bulk_gen_org_completed"
    t.index ["organization_id"], name: "index_bulk_generations_on_organization_id"
    t.index ["session_id"], name: "index_bulk_generations_on_session_id", unique: true
    t.index ["user_id"], name: "index_bulk_generations_on_user_id"
  end

  create_table "collection_schedules", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "assigned_to_id", null: false
    t.date "scheduled_date", null: false
    t.decimal "amount_expected", precision: 12, scale: 2, default: "0.0", null: false
    t.string "status", default: "planned", null: false
    t.text "notes"
    t.bigint "completed_payment_id"
    t.date "rescheduled_to"
    t.string "skip_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id", "scheduled_date", "status"], name: "idx_collection_schedules_assigned_date_status"
    t.index ["assigned_to_id"], name: "index_collection_schedules_on_assigned_to_id"
    t.index ["branch_id"], name: "index_collection_schedules_on_branch_id"
    t.index ["completed_payment_id"], name: "index_collection_schedules_on_completed_payment_id"
    t.index ["customer_id", "scheduled_date"], name: "idx_collection_schedules_customer_date"
    t.index ["customer_id"], name: "index_collection_schedules_on_customer_id"
    t.index ["organization_id", "branch_id", "scheduled_date"], name: "idx_collection_schedules_org_branch_date"
    t.index ["organization_id"], name: "index_collection_schedules_on_organization_id"
  end

  create_table "confidence_adjustments", force: :cascade do |t|
    t.float "amount_tolerance_pct", default: 2.0
    t.integer "date_tolerance_days", default: 3
    t.float "customer_fuzzy_minimum", default: 0.8
    t.integer "reference_weight", default: 15
    t.integer "auto_post_threshold", default: 95
    t.integer "suggestion_threshold", default: 85
    t.integer "rejection_window_minutes", default: 60
    t.integer "model_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_version"], name: "idx_confidence_adjustments_model_version", unique: true
  end

  create_table "credit_accounts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.decimal "credit_limit", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "current_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "available_credit", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "overdue_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "overdue_days", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "collection_first", default: false, null: false
    t.boolean "hold_required", default: false, null: false
    t.boolean "watchlist", default: false, null: false
    t.string "overdue_bucket_cached"
    t.index ["branch_id"], name: "index_credit_accounts_on_branch_id"
    t.index ["customer_id", "organization_id"], name: "idx_credit_accounts_customer_org_unique", unique: true
    t.index ["customer_id"], name: "index_credit_accounts_on_customer_id"
    t.index ["organization_id", "customer_id"], name: "idx_credit_accounts_overdue", where: "(current_balance > (0)::numeric)"
    t.index ["organization_id"], name: "index_credit_accounts_on_organization_id"
    t.check_constraint "credit_limit >= 0::numeric", name: "chk_credit_accounts_credit_limit_non_negative"
  end

  create_table "credit_limit_change_requests", force: :cascade do |t|
    t.bigint "credit_account_id", null: false
    t.bigint "requested_by_id", null: false
    t.bigint "decided_by_id"
    t.decimal "new_limit", precision: 12, scale: 2, null: false
    t.decimal "counter_offer_limit", precision: 12, scale: 2
    t.string "status", default: "pending", null: false
    t.text "reason", null: false
    t.text "supporting_notes"
    t.text "decision_note"
    t.datetime "decided_at"
    t.datetime "sla_breached_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_account_id", "status"], name: "idx_clcr_account_status"
    t.index ["credit_account_id"], name: "index_credit_limit_change_requests_on_credit_account_id"
    t.index ["decided_by_id"], name: "index_credit_limit_change_requests_on_decided_by_id"
    t.index ["requested_by_id"], name: "index_credit_limit_change_requests_on_requested_by_id"
    t.index ["status"], name: "index_credit_limit_change_requests_on_status"
  end

  create_table "credit_note_applications", force: :cascade do |t|
    t.bigint "credit_note_id", null: false
    t.bigint "sales_invoice_id", null: false
    t.bigint "applied_by_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "status", default: "active", null: false
    t.datetime "reversed_at"
    t.text "reversal_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_by_id"], name: "index_credit_note_applications_on_applied_by_id"
    t.index ["credit_note_id", "sales_invoice_id"], name: "idx_cn_applications_cn_invoice"
    t.index ["credit_note_id"], name: "index_credit_note_applications_on_credit_note_id"
    t.index ["sales_invoice_id"], name: "index_credit_note_applications_on_sales_invoice_id"
  end

  create_table "credit_note_lines", force: :cascade do |t|
    t.bigint "credit_note_id", null: false
    t.bigint "product_id", null: false
    t.bigint "return_line_id"
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.string "hsn_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_note_id"], name: "index_credit_note_lines_on_credit_note_id"
    t.index ["product_id"], name: "index_credit_note_lines_on_product_id"
    t.index ["return_line_id"], name: "index_credit_note_lines_on_return_line_id"
  end

  create_table "credit_notes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "return_request_id"
    t.bigint "sales_order_id"
    t.bigint "created_by_id", null: false
    t.string "credit_note_number", null: false
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "tax_total", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 14, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "issued_at"
    t.datetime "voided_at"
    t.text "void_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "applied_to_invoice_id"
    t.decimal "unapplied_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "applied_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "adjustment_type", default: "manual"
    t.index ["applied_to_invoice_id"], name: "index_credit_notes_on_applied_to_invoice_id"
    t.index ["branch_id"], name: "index_credit_notes_on_branch_id"
    t.index ["created_by_id"], name: "index_credit_notes_on_created_by_id"
    t.index ["customer_id", "status"], name: "index_credit_notes_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_credit_notes_on_customer_id"
    t.index ["deleted_at"], name: "index_credit_notes_on_deleted_at"
    t.index ["organization_id", "credit_note_number"], name: "index_credit_notes_on_organization_id_and_credit_note_number", unique: true
    t.index ["organization_id", "status"], name: "index_credit_notes_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_credit_notes_on_organization_id"
    t.index ["return_request_id"], name: "index_credit_notes_on_return_request_id"
    t.index ["sales_order_id"], name: "index_credit_notes_on_sales_order_id"
  end

  create_table "credit_policies", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.integer "hard_block_overdue_days", default: 30, null: false
    t.decimal "hard_block_margin_pct", precision: 6, scale: 2, default: "20.0", null: false
    t.integer "soft_hold_overdue_days_min", default: 15, null: false
    t.integer "soft_hold_overdue_days_max", default: 29, null: false
    t.decimal "soft_hold_outstanding_pct", precision: 6, scale: 2, default: "100.0", null: false
    t.string "collection_first_bucket", default: "serious", null: false
    t.integer "approval_sla_hours_manager", default: 4, null: false
    t.integer "approval_sla_hours_owner", default: 8, null: false
    t.string "auto_invoice_trigger", default: "on_delivery", null: false
    t.boolean "allow_partial_allocation", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_credit_policies_on_organization_id", unique: true
  end

  create_table "customer_addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "label", default: "billing"
    t.string "line1"
    t.string "line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "India"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_addresses_on_customer_id"
    t.index ["label"], name: "index_customer_addresses_on_label"
  end

  create_table "customer_aliases", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "alias_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alias_name"], name: "index_customer_aliases_on_alias_name"
    t.index ["customer_id"], name: "index_customer_aliases_on_customer_id"
  end

  create_table "customer_contacts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "email"
    t.string "designation"
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "is_primary"], name: "idx_customer_contacts_primary"
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "channel"
    t.string "tier"
    t.decimal "credit_limit", precision: 12, scale: 2, default: "0.0"
    t.string "gstin"
    t.string "pan"
    t.string "phone"
    t.string "email"
    t.string "status", default: "active", null: false
    t.bigint "branch_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "route_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "customer_type", default: "retailer"
    t.string "visit_frequency"
    t.integer "credit_days", default: 30
    t.string "credit_block_rule", default: "none"
    t.decimal "opening_balance", precision: 12, scale: 2, default: "0.0"
    t.text "tag_list", default: [], array: true
    t.bigint "sales_rep_id"
    t.datetime "last_visited_at"
    t.date "next_due_on"
    t.string "tally_ledger_name"
    t.decimal "tally_closing_balance", precision: 15, scale: 2
    t.date "tally_balance_as_of_date"
    t.datetime "dunning_suspended_at", comment: "When customer account was suspended due to dunning"
    t.string "dunning_suspension_reason", comment: "Which dunning step triggered suspension (day_10)"
    t.bigint "dunning_suspension_invoice_id", comment: "Which invoice triggered the suspension"
    t.index ["branch_id"], name: "index_customers_on_branch_id"
    t.index ["channel"], name: "index_customers_on_channel"
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["deleted_at"], name: "index_customers_on_deleted_at"
    t.index ["dunning_suspended_at"], name: "index_customers_on_dunning_suspended_at", where: "(dunning_suspended_at IS NOT NULL)"
    t.index ["last_visited_at"], name: "index_customers_on_last_visited_at"
    t.index ["next_due_on"], name: "index_customers_on_next_due_on"
    t.index ["organization_id", "code"], name: "idx_customers_org_code", unique: true
    t.index ["organization_id", "gstin"], name: "idx_customers_org_gstin_unique", unique: true, where: "((gstin IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "phone"], name: "idx_customers_org_phone_unique", unique: true, where: "((phone IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
    t.index ["route_id"], name: "index_customers_on_route_id"
    t.index ["sales_rep_id"], name: "index_customers_on_sales_rep_id"
    t.index ["status"], name: "index_customers_on_status"
    t.index ["tag_list"], name: "index_customers_on_tag_list", using: :gin
    t.index ["tally_ledger_name"], name: "index_customers_on_tally_ledger_name", where: "(tally_ledger_name IS NOT NULL)"
    t.index ["tier"], name: "index_customers_on_tier"
  end

  create_table "delivery_proofs", force: :cascade do |t|
    t.bigint "trip_stop_id", null: false
    t.string "proof_type", default: "photo", null: false
    t.string "otp_code_digest"
    t.datetime "otp_verified_at"
    t.string "override_reason"
    t.bigint "overridden_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "otp_sent_at"
    t.integer "otp_attempts", default: 0
    t.string "otp_proof_type"
    t.index ["otp_sent_at"], name: "index_delivery_proofs_on_otp_sent_at"
    t.index ["proof_type"], name: "index_delivery_proofs_on_proof_type"
    t.index ["trip_stop_id"], name: "index_delivery_proofs_on_trip_stop_id"
  end

  create_table "delivery_rejections", force: :cascade do |t|
    t.bigint "trip_stop_id", null: false
    t.bigint "sales_order_id", null: false
    t.bigint "product_id", null: false
    t.bigint "rejected_by_id", null: false
    t.decimal "qty_rejected", precision: 14, scale: 3, null: false
    t.string "reason_code", null: false
    t.string "condition", default: "unopened", null: false
    t.text "notes"
    t.boolean "auto_return", default: true, null: false
    t.bigint "return_request_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_delivery_rejections_on_product_id"
    t.index ["reason_code"], name: "index_delivery_rejections_on_reason_code"
    t.index ["rejected_by_id"], name: "index_delivery_rejections_on_rejected_by_id"
    t.index ["return_request_id"], name: "index_delivery_rejections_on_return_request_id"
    t.index ["sales_order_id"], name: "index_delivery_rejections_on_sales_order_id"
    t.index ["trip_stop_id"], name: "index_delivery_rejections_on_trip_stop_id"
  end

  create_table "delivery_trips", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "vehicle_id"
    t.bigint "driver_id"
    t.string "trip_number", null: false
    t.date "trip_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.string "cancellation_reason"
    t.datetime "dispatched_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "route_id"
    t.index ["branch_id"], name: "index_delivery_trips_on_branch_id"
    t.index ["driver_id"], name: "index_delivery_trips_on_driver_id"
    t.index ["organization_id", "trip_number"], name: "index_delivery_trips_on_organization_id_and_trip_number", unique: true
    t.index ["organization_id"], name: "index_delivery_trips_on_organization_id"
    t.index ["route_id"], name: "index_delivery_trips_on_route_id"
    t.index ["status"], name: "index_delivery_trips_on_status"
    t.index ["trip_date"], name: "index_delivery_trips_on_trip_date"
    t.index ["vehicle_id"], name: "index_delivery_trips_on_vehicle_id"
  end

  create_table "device_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "token", null: false
    t.string "platform", null: false
    t.string "device_name"
    t.boolean "active", default: true, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "idx_device_tokens_org_active"
    t.index ["organization_id"], name: "index_device_tokens_on_organization_id"
    t.index ["user_id", "token"], name: "idx_device_tokens_user_token", unique: true
    t.index ["user_id"], name: "index_device_tokens_on_user_id"
  end

  create_table "documents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "reference_id"
    t.string "document_type", null: false
    t.string "filename", null: false
    t.string "status", default: "generated", null: false
    t.integer "size_bytes", null: false
    t.string "file_hash"
    t.binary "content", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "generated_by_user_id"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_type"], name: "index_documents_on_document_type"
    t.index ["generated_by_user_id"], name: "index_documents_on_generated_by_user_id"
    t.index ["organization_id", "created_at"], name: "index_documents_on_organization_id_and_created_at"
    t.index ["organization_id", "document_type"], name: "index_documents_on_organization_id_and_document_type"
    t.index ["organization_id", "reference_id"], name: "index_documents_on_organization_id_and_reference_id"
    t.index ["organization_id"], name: "index_documents_on_organization_id"
    t.index ["status", "created_at"], name: "idx_documents_status_created_at"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "ewaybill_requests", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "sales_invoice_id"
    t.string "requestable_type"
    t.bigint "requestable_id"
    t.string "ewaybill_number"
    t.string "status", default: "pending", null: false
    t.string "transport_mode", default: "road", null: false
    t.string "vehicle_number"
    t.string "transporter_id"
    t.string "transporter_name"
    t.decimal "distance_km", precision: 10, scale: 2
    t.string "from_state"
    t.string "to_state"
    t.string "from_pincode"
    t.string "to_pincode"
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.jsonb "response_json", default: {}
    t.text "error_message"
    t.datetime "generated_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ewaybill_number"], name: "index_ewaybill_requests_on_ewaybill_number", unique: true, where: "(ewaybill_number IS NOT NULL)"
    t.index ["organization_id"], name: "index_ewaybill_requests_on_organization_id"
    t.index ["requestable_type", "requestable_id"], name: "idx_ewaybill_requestable"
    t.index ["sales_invoice_id"], name: "index_ewaybill_requests_on_sales_invoice_id"
    t.index ["status"], name: "index_ewaybill_requests_on_status"
  end

  create_table "expected_payment_references", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "customer_id"
    t.bigint "sales_invoice_id"
    t.string "reference_type", null: false
    t.string "reference_value", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_expected_payment_references_on_customer_id"
    t.index ["organization_id"], name: "index_expected_payment_references_on_organization_id"
    t.index ["reference_value"], name: "index_expected_payment_references_on_reference_value"
    t.index ["sales_invoice_id"], name: "index_expected_payment_references_on_sales_invoice_id"
    t.index ["status"], name: "index_expected_payment_references_on_status"
  end

  create_table "exports", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "export_type", null: false
    t.string "status", default: "pending", null: false
    t.string "format", default: "csv", null: false
    t.jsonb "filters", default: {}, null: false
    t.text "error_message"
    t.integer "row_count"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status", "created_at"], name: "idx_exports_org_status_created"
    t.index ["organization_id"], name: "index_exports_on_organization_id"
    t.index ["requested_by_id", "created_at"], name: "idx_exports_user_created"
    t.index ["requested_by_id"], name: "index_exports_on_requested_by_id"
  end

  create_table "financial_years", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "code", null: false
    t.string "label", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "starts_on_month", default: 4, null: false
    t.integer "starts_on_day", default: 1, null: false
    t.string "status", default: "open", null: false
    t.datetime "books_locked_at"
    t.datetime "gst_locked_at"
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.text "notes"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_id"], name: "index_financial_years_on_closed_by_id"
    t.index ["organization_id", "code"], name: "idx_financial_years_org_code_unique", unique: true
    t.index ["organization_id", "start_date"], name: "idx_financial_years_org_start_date"
    t.index ["organization_id", "status"], name: "idx_financial_years_org_status"
    t.index ["status"], name: "index_financial_years_on_status"
  end

  create_table "gst2b_import_lines", force: :cascade do |t|
    t.bigint "gst2b_import_id", null: false
    t.bigint "organization_id", null: false
    t.string "supplier_gstin", null: false
    t.string "supplier_name"
    t.string "invoice_number", null: false
    t.date "invoice_date"
    t.decimal "invoice_value", precision: 16, scale: 2, default: "0.0"
    t.decimal "taxable_value", precision: 16, scale: 2, default: "0.0"
    t.decimal "igst", precision: 14, scale: 2, default: "0.0"
    t.decimal "cgst", precision: 14, scale: 2, default: "0.0"
    t.decimal "sgst", precision: 14, scale: 2, default: "0.0"
    t.decimal "cess", precision: 14, scale: 2, default: "0.0"
    t.string "document_type", default: "invoice"
    t.string "section_type", default: "b2b"
    t.string "place_of_supply"
    t.boolean "reverse_charge", default: false, null: false
    t.boolean "itc_available", default: true, null: false
    t.string "itc_reversal_reason"
    t.bigint "matched_purchase_invoice_id"
    t.string "match_status", default: "pending", null: false
    t.decimal "match_confidence", precision: 5, scale: 2
    t.jsonb "match_explanation", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gst2b_import_id"], name: "idx_gst2b_lines_import_id"
    t.index ["invoice_date"], name: "index_gst2b_import_lines_on_invoice_date"
    t.index ["match_status"], name: "idx_gst2b_lines_match_status"
    t.index ["matched_purchase_invoice_id"], name: "idx_gst2b_lines_matched_pi"
    t.index ["organization_id", "supplier_gstin", "invoice_number"], name: "idx_gst2b_lines_gstin_number"
    t.index ["supplier_gstin"], name: "index_gst2b_import_lines_on_supplier_gstin"
  end

  create_table "gst2b_imports", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "financial_year_id", null: false
    t.string "financial_year_label"
    t.integer "month", null: false
    t.integer "year", null: false
    t.date "period_start_on", null: false
    t.date "period_end_on", null: false
    t.string "gstin", null: false
    t.string "file_name"
    t.string "source_type", default: "json", null: false
    t.string "import_status", default: "uploaded", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.jsonb "parsed_summary", default: {}, null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "matched_rows", default: 0, null: false
    t.integer "unmatched_rows", default: 0, null: false
    t.integer "error_rows", default: 0, null: false
    t.datetime "imported_at"
    t.bigint "imported_by_id"
    t.string "source_hash"
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_gst2b_imports_on_branch_id"
    t.index ["financial_year_id"], name: "index_gst2b_imports_on_financial_year_id"
    t.index ["import_status"], name: "index_gst2b_imports_on_import_status"
    t.index ["imported_by_id"], name: "index_gst2b_imports_on_imported_by_id"
    t.index ["organization_id", "financial_year_id", "month", "year"], name: "idx_gst2b_imports_org_fy_period"
    t.index ["organization_id", "source_hash"], name: "idx_gst2b_imports_source_hash"
  end

  create_table "gst_amendment_candidates", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "gst_return_period_id", null: false
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.string "amendment_type", null: false
    t.string "status", default: "detected", null: false
    t.decimal "taxable_value_original", precision: 16, scale: 2
    t.decimal "taxable_value_current", precision: 16, scale: 2
    t.decimal "tax_original", precision: 16, scale: 2
    t.decimal "tax_current", precision: 16, scale: 2
    t.text "change_summary"
    t.datetime "detected_at", null: false
    t.bigint "acknowledged_by_id"
    t.datetime "acknowledged_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gst_return_period_id", "amendment_type"], name: "idx_gst_amc_on_period_and_type"
    t.index ["gst_return_period_id"], name: "index_gst_amendment_candidates_on_gst_return_period_id"
    t.index ["organization_id", "gst_return_period_id"], name: "idx_gst_amc_on_org_and_period"
    t.index ["organization_id"], name: "index_gst_amendment_candidates_on_organization_id"
    t.index ["source_type", "source_id"], name: "idx_gst_amc_on_source"
    t.index ["status"], name: "idx_gst_amc_on_status"
  end

  create_table "gst_reconciliation_issues", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "financial_year_id", null: false
    t.bigint "gst_return_period_id"
    t.bigint "gst2b_import_id"
    t.string "issue_type", null: false
    t.string "severity", default: "medium", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.string "counterpart_type"
    t.bigint "counterpart_id"
    t.string "supplier_gstin"
    t.string "customer_gstin"
    t.string "invoice_number"
    t.date "invoice_date"
    t.decimal "amount_books", precision: 16, scale: 2
    t.decimal "amount_portal", precision: 16, scale: 2
    t.decimal "difference_amount", precision: 16, scale: 2
    t.string "status", default: "open", null: false
    t.text "resolution_notes"
    t.bigint "resolved_by_id"
    t.datetime "resolved_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["financial_year_id"], name: "index_gst_reconciliation_issues_on_financial_year_id"
    t.index ["gst2b_import_id"], name: "index_gst_reconciliation_issues_on_gst2b_import_id"
    t.index ["gst_return_period_id"], name: "index_gst_reconciliation_issues_on_gst_return_period_id"
    t.index ["organization_id", "financial_year_id", "issue_type"], name: "idx_gst_recon_issues_org_fy_type"
    t.index ["organization_id", "status"], name: "idx_gst_recon_issues_org_status"
    t.index ["resolved_by_id"], name: "index_gst_reconciliation_issues_on_resolved_by_id"
    t.index ["severity"], name: "index_gst_reconciliation_issues_on_severity"
    t.index ["source_type", "source_id"], name: "idx_gst_recon_issues_source"
    t.index ["status"], name: "index_gst_reconciliation_issues_on_status"
  end

  create_table "gst_return_periods", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "financial_year_id", null: false
    t.string "financial_year_label"
    t.integer "month", null: false
    t.integer "year", null: false
    t.date "period_start_on", null: false
    t.date "period_end_on", null: false
    t.string "return_type", null: false
    t.string "status", default: "draft", null: false
    t.datetime "generated_at"
    t.datetime "locked_at"
    t.datetime "filed_at"
    t.bigint "filed_by_id"
    t.bigint "locked_by_id"
    t.bigint "reviewed_by_id"
    t.string "source_hash"
    t.string "snapshot_hash"
    t.text "filing_notes"
    t.integer "error_count", default: 0, null: false
    t.integer "warning_count", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_gst_return_periods_on_branch_id"
    t.index ["filed_by_id"], name: "index_gst_return_periods_on_filed_by_id"
    t.index ["financial_year_id"], name: "index_gst_return_periods_on_financial_year_id"
    t.index ["organization_id", "financial_year_id", "month", "year", "return_type", "branch_id"], name: "idx_gst_return_periods_unique", unique: true, where: "(branch_id IS NOT NULL)"
    t.index ["organization_id", "financial_year_id", "month", "year", "return_type"], name: "idx_gst_return_periods_unique_no_branch", unique: true, where: "(branch_id IS NULL)"
    t.index ["organization_id", "return_type", "year", "month"], name: "idx_gst_return_periods_org_type_period"
    t.index ["organization_id", "status"], name: "idx_gst_return_periods_org_status"
    t.index ["status"], name: "index_gst_return_periods_on_status"
  end

  create_table "gst_return_snapshots", force: :cascade do |t|
    t.bigint "gst_return_period_id", null: false
    t.bigint "organization_id", null: false
    t.string "section_key", null: false
    t.jsonb "payload", default: {}, null: false
    t.jsonb "totals", default: {}, null: false
    t.jsonb "source_counts", default: {}, null: false
    t.jsonb "source_invoice_ids", default: [], null: false
    t.datetime "generated_at", null: false
    t.integer "version_number", default: 1, null: false
    t.string "source_hash"
    t.string "snapshot_hash"
    t.boolean "is_filed", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_at"], name: "index_gst_return_snapshots_on_generated_at"
    t.index ["gst_return_period_id", "is_filed"], name: "idx_gst_snapshots_period_filed"
    t.index ["gst_return_period_id", "section_key", "version_number"], name: "idx_gst_snapshots_period_section_version"
    t.index ["organization_id"], name: "index_gst_return_snapshots_on_organization_id"
  end

  create_table "gstr1_export_records", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "generated_by_id"
    t.string "gstin", null: false
    t.string "return_period", null: false
    t.date "period_from", null: false
    t.date "period_to", null: false
    t.string "status", default: "pending", null: false
    t.integer "b2b_count", default: 0, null: false
    t.integer "b2cl_count", default: 0, null: false
    t.integer "b2cs_count", default: 0, null: false
    t.integer "cdnr_count", default: 0, null: false
    t.integer "cdnur_count", default: 0, null: false
    t.integer "total_invoice_count", default: 0, null: false
    t.integer "total_cn_count", default: 0, null: false
    t.decimal "total_taxable_value", precision: 16, scale: 2, default: "0.0"
    t.decimal "total_tax_value", precision: 16, scale: 2, default: "0.0"
    t.decimal "total_invoice_value", precision: 16, scale: 2, default: "0.0"
    t.integer "error_count", default: 0, null: false
    t.integer "warning_count", default: 0, null: false
    t.jsonb "validation_report", default: {}, null: false
    t.string "file_path"
    t.string "checksum"
    t.text "error_message"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_gstr1_export_records_on_branch_id"
    t.index ["generated_by_id"], name: "index_gstr1_export_records_on_generated_by_id"
    t.index ["organization_id", "return_period"], name: "idx_gstr1_exports_org_period"
    t.index ["organization_id"], name: "index_gstr1_export_records_on_organization_id"
    t.index ["status"], name: "index_gstr1_export_records_on_status"
  end

  create_table "hsn_sac_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "code_type", default: "HSN", null: false
    t.string "description"
    t.string "chapter"
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "cgst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "sgst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "igst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cess_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.string "cess_type", default: "none", null: false
    t.decimal "cess_specific_amount", precision: 14, scale: 2
    t.index ["code", "effective_from"], name: "idx_hsn_sac_codes_on_code_effective_from"
    t.index ["code"], name: "idx_hsn_sac_codes_current_active", where: "((active = true) AND (effective_to IS NULL))"
    t.index ["code_type"], name: "index_hsn_sac_codes_on_code_type"
    t.index ["gst_rate"], name: "index_hsn_sac_codes_on_gst_rate"
  end

  create_table "inventory_levels", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty_on_hand", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "qty_reserved", precision: 14, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "min_qty_threshold", precision: 14, scale: 3
    t.index ["branch_id", "product_id"], name: "idx_inventory_levels_branch_product"
    t.index ["branch_id", "product_id"], name: "index_inventory_levels_branch_product", unique: true
    t.index ["branch_id"], name: "index_inventory_levels_on_branch_id"
    t.index ["organization_id"], name: "index_inventory_levels_on_organization_id"
    t.index ["product_id"], name: "index_inventory_levels_on_product_id"
    t.check_constraint "qty_on_hand >= 0::numeric", name: "chk_inventory_levels_qty_on_hand_non_negative"
    t.check_constraint "qty_reserved >= 0::numeric", name: "chk_inventory_levels_qty_reserved_non_negative"
  end

  create_table "inventory_reservations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "product_id", null: false
    t.bigint "sales_order_id", null: false
    t.bigint "sales_order_line_id"
    t.decimal "qty_reserved", precision: 14, scale: 3, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "product_id", "status"], name: "index_inventory_reservations_by_product_status"
    t.index ["branch_id"], name: "index_inventory_reservations_on_branch_id"
    t.index ["organization_id"], name: "index_inventory_reservations_on_organization_id"
    t.index ["product_id"], name: "index_inventory_reservations_on_product_id"
    t.index ["sales_order_id"], name: "index_inventory_reservations_on_sales_order_id"
    t.index ["sales_order_line_id"], name: "index_inventory_reservations_on_sales_order_line_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.string "token_digest", null: false
    t.bigint "organization_id", null: false
    t.bigint "role_id", null: false
    t.bigint "branch_id"
    t.bigint "invited_by_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["organization_id", "email"], name: "idx_invitations_org_email"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "invoice_generation_quarantines", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "trip_stop_id", null: false
    t.bigint "sales_order_id", null: false
    t.bigint "branch_id", null: false
    t.text "error_message", null: false
    t.text "error_backtrace"
    t.integer "retry_count", default: 0, null: false
    t.datetime "last_retry_at"
    t.jsonb "delivered_lines", default: {}, null: false, comment: "Snapshot of delivered line items for retry"
    t.jsonb "error_context", default: {}, comment: "Additional context (retry reason code, etc.)"
    t.string "status", default: "quarantined", null: false, comment: "quarantined, processing, resolved, archived"
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_invoice_generation_quarantines_on_branch_id"
    t.index ["created_at", "status"], name: "index_invoice_generation_quarantines_on_created_at_and_status"
    t.index ["organization_id", "status"], name: "idx_on_organization_id_status_8171273d98"
    t.index ["organization_id"], name: "index_invoice_generation_quarantines_on_organization_id"
    t.index ["resolved_by_id"], name: "index_invoice_generation_quarantines_on_resolved_by_id"
    t.index ["sales_order_id"], name: "index_invoice_generation_quarantines_on_sales_order_id"
    t.index ["trip_stop_id"], name: "index_invoice_generation_quarantines_on_trip_stop_id", comment: "One quarantine per trip stop"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "login_attempts", force: :cascade do |t|
    t.bigint "user_id", comment: "null if account not found"
    t.string "identifier_type", null: false, comment: "password, otp, google, magic_link"
    t.string "identifier", null: false, comment: "email, phone, or oauth provider"
    t.boolean "success", default: false, null: false
    t.string "failure_reason", comment: "wrong_password, otp_expired, account_locked, user_not_found, etc"
    t.inet "ip_address", comment: "IPv4 or IPv6 address of login attempt"
    t.string "user_agent", comment: "Browser/device information"
    t.string "fingerprint", comment: "Device fingerprint for risk detection"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier_type", "identifier", "created_at"], name: "idx_login_attempts_identifier_time"
    t.index ["ip_address", "success", "created_at"], name: "idx_login_attempts_ip_success"
    t.index ["user_id", "created_at"], name: "idx_login_attempts_user_time"
    t.index ["user_id", "success", "created_at"], name: "idx_login_failed_attempts", where: "(success = false)"
    t.index ["user_id"], name: "index_login_attempts_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "role_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "active", null: false
    t.index ["branch_id"], name: "index_memberships_on_branch_id"
    t.index ["deleted_at"], name: "index_memberships_on_deleted_at"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["role_id"], name: "index_memberships_on_role_id"
    t.index ["status"], name: "index_memberships_on_status"
    t.index ["user_id", "organization_id", "branch_id"], name: "idx_memberships_unique", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "body"
    t.string "deep_link_url"
    t.string "severity", default: "medium", null: false
    t.datetime "read_at"
    t.datetime "dismissed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "idx_notifications_notifiable"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["user_id", "organization_id", "created_at"], name: "idx_notifications_user_org_created"
    t.index ["user_id", "read_at"], name: "idx_unread_notifications", where: "(read_at IS NULL)"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "onboarding_progresses", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "steps", default: {}, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "user_id"], name: "idx_onboarding_org_user", unique: true
    t.index ["organization_id"], name: "index_onboarding_progresses_on_organization_id"
    t.index ["user_id"], name: "index_onboarding_progresses_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "plan", default: "starter", null: false
    t.boolean "active", default: true, null: false
    t.string "gst_number"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pan"
    t.string "logo_url"
    t.string "timezone", default: "Asia/Kolkata"
    t.string "currency", default: "INR"
    t.jsonb "settings", default: {}, null: false
    t.string "billing_status", default: "inactive", null: false
    t.string "razorpay_customer_id"
    t.datetime "current_period_end"
    t.datetime "trial_ends_at"
    t.jsonb "dunning_config", default: {"day_1"=>{"type"=>"friendly_reminder", "enabled"=>true}, "day_5"=>{"type"=>"urgent_notice", "enabled"=>true}, "day_10"=>{"type"=>"final_notice", "action"=>"suspend_account", "enabled"=>true}, "enabled"=>false, "quiet_hours_end"=>8, "quiet_hours_start"=>22, "max_reminders_per_month"=>3}, null: false
    t.index ["billing_status"], name: "index_organizations_on_billing_status"
    t.index ["razorpay_customer_id"], name: "index_organizations_on_razorpay_customer_id", unique: true, where: "(razorpay_customer_id IS NOT NULL)"
    t.index ["settings"], name: "index_organizations_on_settings", using: :gin
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "otp_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.string "request_id", null: false
    t.string "identifier", null: false, comment: "Email or phone number being verified"
    t.integer "identifier_type", default: 0, null: false, comment: "0=email, 1=phone"
    t.string "otp_code", null: false
    t.integer "otp_attempts", default: 0, null: false
    t.datetime "otp_sent_at"
    t.boolean "verified", default: false, null: false
    t.datetime "verified_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier", "identifier_type"], name: "index_otp_requests_on_identifier_and_identifier_type"
    t.index ["identifier_type"], name: "index_otp_requests_on_identifier_type"
    t.index ["request_id"], name: "index_otp_requests_on_request_id", unique: true
    t.index ["user_id"], name: "index_otp_requests_on_user_id"
  end

  create_table "payment_allocations", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "sales_invoice_id", null: false
    t.decimal "allocated_amount", precision: 14, scale: 2, null: false
    t.string "status", default: "active", null: false
    t.datetime "reversed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id", "sales_invoice_id"], name: "idx_allocations_payment_invoice"
    t.index ["payment_id"], name: "index_payment_allocations_on_payment_id"
    t.index ["sales_invoice_id"], name: "idx_allocations_invoice"
    t.index ["sales_invoice_id"], name: "index_payment_allocations_on_sales_invoice_id"
    t.index ["status"], name: "idx_allocations_status"
  end

  create_table "payment_suggestions", force: :cascade do |t|
    t.bigint "bank_transaction_id", null: false
    t.bigint "invoice_id", null: false
    t.float "confidence_score"
    t.jsonb "confidence_breakdown", default: {}, null: false
    t.string "status", limit: 50, default: "pending_approval"
    t.bigint "approved_by"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_transaction_id"], name: "idx_payment_suggestions_bank_transaction_id"
    t.index ["invoice_id"], name: "idx_payment_suggestions_invoice_id"
    t.index ["status"], name: "idx_payment_suggestions_status"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "created_by_id", null: false
    t.string "payment_number", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "payment_mode", default: "cash", null: false
    t.string "reference_number"
    t.date "received_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.decimal "allocated_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "unallocated_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "confirmed_at"
    t.datetime "reversed_at"
    t.text "reversal_reason"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "idempotency_key"
    t.string "tally_voucher_number"
    t.datetime "tally_sync_at"
    t.string "external_payment_id"
    t.jsonb "external_payload_data", default: {}
    t.string "external_payment_status"
    t.datetime "external_confirmed_at"
    t.string "failed_reason", comment: "Reason for payment failure (e.g., \"insufficient_funds\", \"card_declined\", \"network_error\")"
    t.integer "retry_count", default: 0, comment: "Number of retry attempts made"
    t.datetime "next_retry_at", comment: "Timestamp of scheduled next retry"
    t.datetime "last_retry_at", comment: "Timestamp of last retry attempt"
    t.string "retry_status", default: "pending", comment: "pending | scheduled | completed | abandoned"
    t.boolean "auto_posted", default: false
    t.float "confidence_score"
    t.datetime "rejection_window_expires_at"
    t.bigint "reversed_by"
    t.index ["auto_posted", "rejection_window_expires_at"], name: "idx_payments_auto_posted_window"
    t.index ["branch_id"], name: "index_payments_on_branch_id"
    t.index ["created_by_id"], name: "index_payments_on_created_by_id"
    t.index ["customer_id", "received_date"], name: "idx_payments_customer_payment_date"
    t.index ["customer_id", "status"], name: "idx_payments_customer_status"
    t.index ["customer_id"], name: "index_payments_on_customer_id"
    t.index ["external_payment_id"], name: "index_payments_on_external_payment_id", unique: true, where: "(external_payment_id IS NOT NULL)"
    t.index ["external_payment_status", "retry_count"], name: "idx_payments_failed_retryable", where: "((external_payment_status)::text = 'failed'::text)"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["metadata"], name: "idx_payments_metadata", using: :gin
    t.index ["organization_id", "external_payment_status"], name: "idx_payments_org_ext_status"
    t.index ["organization_id", "payment_number"], name: "idx_payments_org_number", unique: true
    t.index ["organization_id", "status"], name: "idx_payments_org_status"
    t.index ["organization_id"], name: "index_payments_on_organization_id"
    t.index ["payment_mode"], name: "idx_payments_mode"
    t.index ["received_date"], name: "idx_payments_received_date"
    t.index ["retry_status", "next_retry_at"], name: "idx_payments_retry_scheduling", where: "((retry_status)::text = ANY ((ARRAY['pending'::character varying, 'scheduled'::character varying])::text[]))"
    t.index ["tally_voucher_number"], name: "index_payments_on_tally_voucher_number", where: "(tally_voucher_number IS NOT NULL)"
    t.check_constraint "amount > 0::numeric", name: "chk_payments_amount_positive"
  end

  create_table "pending_registrations", force: :cascade do |t|
    t.string "email", null: false
    t.string "otp_code"
    t.datetime "otp_sent_at"
    t.integer "otp_attempts", default: 0, null: false
    t.string "current_step", default: "initiate", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "expires_at"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "auth_channel", default: "email"
    t.string "phone_number", limit: 10
    t.index ["email"], name: "index_pending_registrations_on_email", unique: true
    t.index ["expires_at"], name: "index_pending_registrations_on_expires_at"
    t.index ["otp_code"], name: "index_pending_registrations_on_otp_code"
    t.index ["phone_number", "auth_channel"], name: "index_pending_registrations_on_phone_number_and_auth_channel"
  end

  create_table "pick_list_items", force: :cascade do |t|
    t.bigint "pick_list_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty_requested", precision: 14, scale: 3, null: false
    t.decimal "qty_picked", precision: 14, scale: 3, default: "0.0", null: false
    t.string "bin_location"
    t.datetime "picked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pick_list_id", "product_id"], name: "index_pick_list_items_on_pick_list_id_and_product_id", unique: true
    t.index ["pick_list_id"], name: "index_pick_list_items_on_pick_list_id"
    t.index ["product_id"], name: "index_pick_list_items_on_product_id"
  end

  create_table "pick_lists", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "sales_order_id", null: false
    t.bigint "picker_id"
    t.string "status", default: "pending", null: false
    t.string "pick_number", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_pick_lists_on_branch_id"
    t.index ["organization_id", "pick_number"], name: "index_pick_lists_on_organization_id_and_pick_number", unique: true
    t.index ["organization_id", "status"], name: "index_pick_lists_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_pick_lists_on_organization_id"
    t.index ["picker_id"], name: "index_pick_lists_on_picker_id"
    t.index ["sales_order_id"], name: "index_pick_lists_on_sales_order_id"
  end

  create_table "prepayment_skus", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "product_id", null: false
    t.bigint "created_by_id", null: false
    t.text "reason", null: false
    t.date "effective_from", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_prepayment_skus_on_branch_id"
    t.index ["created_by_id"], name: "index_prepayment_skus_on_created_by_id"
    t.index ["organization_id", "product_id", "branch_id"], name: "idx_prepayment_skus_active_unique", unique: true, where: "(active = true)"
    t.index ["organization_id"], name: "index_prepayment_skus_on_organization_id"
    t.index ["product_id"], name: "index_prepayment_skus_on_product_id"
  end

  create_table "price_list_items", force: :cascade do |t|
    t.bigint "price_list_id", null: false
    t.bigint "product_id", null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.decimal "min_qty", precision: 10, scale: 3
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["price_list_id", "product_id", "min_qty"], name: "idx_price_list_items_unique", unique: true
    t.index ["price_list_id"], name: "index_price_list_items_on_price_list_id"
    t.index ["product_id"], name: "index_price_list_items_on_product_id"
  end

  create_table "price_lists", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.string "name", null: false
    t.string "list_type", default: "standard", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "list_type", "status"], name: "idx_price_lists_branch_type_status"
    t.index ["branch_id"], name: "index_price_lists_on_branch_id"
    t.index ["deleted_at"], name: "index_price_lists_on_deleted_at"
    t.index ["list_type"], name: "index_price_lists_on_list_type"
    t.index ["organization_id"], name: "index_price_lists_on_organization_id"
    t.index ["status"], name: "index_price_lists_on_status"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "code"
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_product_categories_on_deleted_at"
    t.index ["organization_id", "name"], name: "idx_product_categories_org_name_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_product_categories_on_organization_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "product_category_id", null: false
    t.bigint "units_of_measure_id", null: false
    t.string "sku", null: false
    t.string "name", null: false
    t.string "barcode"
    t.text "description"
    t.bigint "hsn_sac_code_id", null: false
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "min_order_qty", precision: 10, scale: 3, default: "1.0", null: false
    t.decimal "purchase_price", precision: 12, scale: 2
    t.decimal "weight_kg", precision: 8, scale: 3
    t.string "image_url"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_products_on_barcode", where: "(barcode IS NOT NULL)"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["hsn_sac_code_id"], name: "index_products_on_hsn_sac_code_id"
    t.index ["organization_id", "sku"], name: "idx_products_org_sku_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_products_on_organization_id"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["status"], name: "index_products_on_status"
    t.index ["units_of_measure_id"], name: "index_products_on_units_of_measure_id"
  end

  create_table "purchase_invoice_lines", force: :cascade do |t|
    t.bigint "purchase_invoice_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.bigint "hsn_sac_code_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hsn_sac_code_id"], name: "index_purchase_invoice_lines_on_hsn_sac_code_id"
    t.index ["product_id"], name: "index_purchase_invoice_lines_on_product_id"
    t.index ["purchase_invoice_id"], name: "index_purchase_invoice_lines_on_purchase_invoice_id"
  end

  create_table "purchase_invoices", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "supplier_id", null: false
    t.bigint "created_by_id", null: false
    t.string "invoice_number", null: false
    t.date "invoice_date", null: false
    t.date "due_date"
    t.string "status", default: "draft", null: false
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "grand_total", precision: 14, scale: 2, default: "0.0", null: false
    t.string "currency", default: "INR", null: false
    t.text "notes"
    t.datetime "posted_at"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_reverse_charge", default: false, null: false
    t.decimal "rcm_tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "supplier_gstin"
    t.string "place_of_supply"
    t.index ["branch_id"], name: "index_purchase_invoices_on_branch_id"
    t.index ["created_by_id"], name: "index_purchase_invoices_on_created_by_id"
    t.index ["deleted_at"], name: "index_purchase_invoices_on_deleted_at"
    t.index ["invoice_date"], name: "index_purchase_invoices_on_invoice_date"
    t.index ["organization_id"], name: "index_purchase_invoices_on_organization_id"
    t.index ["status"], name: "index_purchase_invoices_on_status"
    t.index ["supplier_id", "invoice_number"], name: "index_purchase_invoices_supplier_number_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["supplier_id"], name: "index_purchase_invoices_on_supplier_id"
  end

  create_table "rejection_feedbacks", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.float "confidence_score"
    t.string "rejection_reason", limit: 255
    t.datetime "timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "idx_rejection_feedbacks_payment_id"
    t.index ["timestamp"], name: "idx_rejection_feedbacks_timestamp"
  end

  create_table "reschedule_deliveries", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "trip_stop_id", null: false
    t.bigint "sales_order_id", null: false
    t.bigint "customer_id"
    t.bigint "new_trip_stop_id"
    t.date "original_date", null: false, comment: "Original delivery date"
    t.date "next_retry_date", comment: "Scheduled retry date"
    t.date "new_trip_date", comment: "Date when rescheduled trip is scheduled"
    t.string "failure_code", comment: "Reason for delivery failure"
    t.text "failure_notes", comment: "Additional notes about failure"
    t.integer "attempt_count", default: 1, comment: "Number of delivery attempts"
    t.integer "max_attempts", default: 3, comment: "Maximum retry attempts before escalation"
    t.string "status", default: "pending", comment: "pending | rescheduled | delivered | cancelled | escalated"
    t.datetime "last_attempted_at", comment: "When last attempt was made"
    t.datetime "rescheduled_at", comment: "When rescheduling was processed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "escalation_data", default: {}, null: false
    t.jsonb "notification_data", default: {}, null: false
    t.index ["customer_id"], name: "index_reschedule_deliveries_on_customer_id"
    t.index ["new_trip_stop_id"], name: "index_reschedule_deliveries_on_new_trip_stop_id"
    t.index ["next_retry_date"], name: "index_reschedule_deliveries_on_next_retry_date", where: "((status)::text = 'pending'::text)"
    t.index ["organization_id", "status"], name: "idx_reschedule_deliveries_pending", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'rescheduled'::character varying])::text[]))"
    t.index ["organization_id"], name: "index_reschedule_deliveries_on_organization_id"
    t.index ["sales_order_id"], name: "index_reschedule_deliveries_on_sales_order_id"
    t.index ["trip_stop_id"], name: "index_reschedule_deliveries_on_trip_stop_id"
  end

  create_table "retailer_price_list_assignments", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "price_list_id", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_retailer_price_list_assignments_on_active"
    t.index ["customer_id", "price_list_id"], name: "idx_retailer_pl_assignment_unique", unique: true
    t.index ["customer_id"], name: "index_retailer_price_list_assignments_on_customer_id"
    t.index ["price_list_id"], name: "index_retailer_price_list_assignments_on_price_list_id"
  end

  create_table "retailer_risk_snapshots", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "customer_id", null: false
    t.integer "risk_score", default: 0, null: false
    t.string "risk_tier", default: "low", null: false
    t.string "recommendation", null: false
    t.jsonb "factors_json", default: {}, null: false
    t.string "score_version", default: "v1", null: false
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "computed_at"], name: "idx_risk_snapshots_customer_time"
    t.index ["organization_id", "risk_tier"], name: "idx_risk_snapshots_org_tier"
    t.index ["organization_id"], name: "index_retailer_risk_snapshots_on_organization_id"
    t.index ["risk_score"], name: "index_retailer_risk_snapshots_on_risk_score"
    t.index ["risk_tier"], name: "index_retailer_risk_snapshots_on_risk_tier"
  end

  create_table "return_lines", force: :cascade do |t|
    t.bigint "return_request_id", null: false
    t.bigint "product_id", null: false
    t.bigint "sales_order_line_id"
    t.decimal "qty_reported", precision: 14, scale: 3, null: false
    t.decimal "qty_accepted", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "qty_rejected", precision: 14, scale: 3, default: "0.0", null: false
    t.string "condition_reported", default: "unknown", null: false
    t.string "reason_code", default: "other", null: false
    t.decimal "unit_price_snapshot", precision: 14, scale: 2
    t.decimal "gst_rate_snapshot", precision: 5, scale: 2
    t.string "hsn_code_snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "batch_number"
    t.date "expiry_date"
    t.date "manufacture_date"
    t.index ["product_id"], name: "index_return_lines_on_product_id"
    t.index ["return_request_id", "product_id"], name: "index_return_lines_on_return_request_id_and_product_id"
    t.index ["return_request_id"], name: "index_return_lines_on_return_request_id"
    t.index ["sales_order_line_id"], name: "index_return_lines_on_sales_order_line_id"
  end

  create_table "return_qc_items", force: :cascade do |t|
    t.bigint "return_line_id", null: false
    t.bigint "qc_by_id", null: false
    t.decimal "qty_resalable", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "qty_damaged", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "qty_expired", precision: 14, scale: 3, default: "0.0", null: false
    t.string "condition_final", default: "resalable", null: false
    t.text "qc_notes"
    t.datetime "qc_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "qty_discounted_resalable", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "qty_return_to_supplier", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "discount_pct", precision: 5, scale: 2
    t.string "supplier_return_reason"
    t.index ["qc_by_id"], name: "index_return_qc_items_on_qc_by_id"
    t.index ["return_line_id"], name: "index_return_qc_items_on_return_line_id"
  end

  create_table "return_records", force: :cascade do |t|
    t.bigint "trip_stop_id", null: false
    t.bigint "product_id", null: false
    t.integer "qty_returned", default: 0, null: false
    t.string "condition", default: "good", null: false
    t.string "reason_code", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "return_request_id"
    t.datetime "deprecated_at", comment: "Set to migration time to mark deprecation. Null = pre-deprecation row."
    t.index ["condition"], name: "index_return_records_on_condition"
    t.index ["product_id"], name: "index_return_records_on_product_id"
    t.index ["reason_code"], name: "index_return_records_on_reason_code"
    t.index ["return_request_id"], name: "index_return_records_on_return_request_id"
    t.index ["trip_stop_id"], name: "index_return_records_on_trip_stop_id"
  end

  create_table "return_requests", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "created_by_id", null: false
    t.string "source_type", default: "manual", null: false
    t.bigint "source_id"
    t.string "return_number", null: false
    t.date "return_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.text "cancellation_reason"
    t.datetime "submitted_at"
    t.datetime "qc_completed_at"
    t.datetime "credit_note_issued_at"
    t.datetime "cancelled_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_return_requests_on_branch_id"
    t.index ["created_by_id"], name: "index_return_requests_on_created_by_id"
    t.index ["customer_id", "status"], name: "index_return_requests_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_return_requests_on_customer_id"
    t.index ["deleted_at"], name: "index_return_requests_on_deleted_at"
    t.index ["organization_id", "return_number"], name: "index_return_requests_on_organization_id_and_return_number", unique: true
    t.index ["organization_id", "status"], name: "index_return_requests_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_return_requests_on_organization_id"
    t.index ["source_type", "source_id"], name: "index_return_requests_on_source_type_and_source_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "routes", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.bigint "branch_id", null: false
    t.bigint "organization_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id"
    t.bigint "default_driver_id"
    t.index ["branch_id", "code"], name: "index_routes_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_routes_on_branch_id"
    t.index ["default_driver_id"], name: "index_routes_on_default_driver_id"
    t.index ["organization_id"], name: "index_routes_on_organization_id"
    t.index ["vehicle_id"], name: "index_routes_on_vehicle_id"
  end

  create_table "sales_invoice_lines", force: :cascade do |t|
    t.bigint "sales_invoice_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0"
    t.decimal "taxable_value", precision: 14, scale: 2, default: "0.0", null: false
    t.string "hsn_code"
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "cgst_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "sgst_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "igst_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "cgst_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "sgst_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "igst_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.bigint "source_sales_order_line_id"
    t.bigint "source_trip_stop_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cess_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "cess_amount", precision: 14, scale: 2, default: "0.0"
    t.index ["product_id"], name: "idx_sil_product_id"
    t.index ["sales_invoice_id"], name: "idx_sil_invoice_id"
    t.index ["source_sales_order_line_id"], name: "idx_sil_order_line_id"
    t.index ["source_trip_stop_id"], name: "idx_sil_stop_id"
  end

  create_table "sales_invoices", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "sales_order_id"
    t.bigint "created_by_id", null: false
    t.string "invoice_number", null: false
    t.date "invoice_date", null: false
    t.date "due_date"
    t.string "status", default: "draft", null: false
    t.decimal "subtotal", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "tax_total", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "grand_total", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "round_off", precision: 8, scale: 2, default: "0.0"
    t.string "currency", default: "INR", null: false
    t.text "notes"
    t.datetime "issued_at"
    t.datetime "voided_at"
    t.text "void_reason"
    t.string "pdf_key"
    t.datetime "pdf_generated_at"
    t.datetime "deleted_at"
    t.string "generation_source", default: "manual_direct"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "outstanding_amount", precision: 14, scale: 2, default: "0.0", null: false, comment: "Unpaid balance; decremented by payment allocations"
    t.decimal "paid_amount", precision: 14, scale: 2, default: "0.0", null: false, comment: "Sum of confirmed payment allocations"
    t.string "irn", comment: "Invoice Reference Number from GST IRP"
    t.datetime "irn_generated_at"
    t.string "ack_number", comment: "IRP acknowledgement number"
    t.string "ack_datetime"
    t.text "einvoice_qr_code", comment: "Signed QR code from IRP"
    t.string "einvoice_status", default: "not_required"
    t.text "einvoice_error"
    t.datetime "paid_at"
    t.jsonb "dunning_attempts", default: {}, null: false
    t.index ["branch_id"], name: "index_sales_invoices_on_branch_id"
    t.index ["created_by_id"], name: "index_sales_invoices_on_created_by_id"
    t.index ["customer_id", "status"], name: "idx_sales_invoices_customer_status"
    t.index ["customer_id"], name: "index_sales_invoices_on_customer_id"
    t.index ["deleted_at"], name: "index_sales_invoices_on_deleted_at"
    t.index ["invoice_date"], name: "index_sales_invoices_on_invoice_date"
    t.index ["irn"], name: "idx_sales_invoices_irn_unique", unique: true, where: "(irn IS NOT NULL)"
    t.index ["metadata"], name: "index_sales_invoices_on_metadata", using: :gin
    t.index ["organization_id", "due_date", "status"], name: "idx_sales_invoices_dunning_query"
    t.index ["organization_id", "invoice_number"], name: "idx_sales_invoices_org_number", unique: true
    t.index ["organization_id", "paid_at"], name: "idx_sales_invoices_org_paid_at"
    t.index ["organization_id", "status"], name: "idx_sales_invoices_org_status"
    t.index ["organization_id"], name: "index_sales_invoices_on_organization_id"
    t.index ["outstanding_amount"], name: "idx_sales_invoices_outstanding"
    t.index ["sales_order_id"], name: "index_sales_invoices_on_sales_order_id"
  end

  create_table "sales_order_freebies", force: :cascade do |t|
    t.bigint "sales_order_id", null: false
    t.bigint "scheme_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty_free", precision: 14, scale: 3, null: false
    t.string "uom"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_sales_order_freebies_on_product_id"
    t.index ["sales_order_id"], name: "index_sales_order_freebies_on_sales_order_id"
    t.index ["scheme_id"], name: "index_sales_order_freebies_on_scheme_id"
  end

  create_table "sales_order_lines", force: :cascade do |t|
    t.bigint "sales_order_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0"
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.string "price_source"
    t.bigint "price_list_id"
    t.string "hsn_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "delivered_qty", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "returned_qty", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "invoiced_qty", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "scheme_discount_pct", precision: 5, scale: 2, default: "0.0"
    t.jsonb "scheme_tags", default: []
    t.index ["invoiced_qty"], name: "idx_sol_invoiced_qty"
    t.index ["price_list_id"], name: "index_sales_order_lines_on_price_list_id"
    t.index ["product_id"], name: "index_sales_order_lines_on_product_id"
    t.index ["sales_order_id"], name: "index_sales_order_lines_on_sales_order_id"
  end

  create_table "sales_orders", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "created_by_id", null: false
    t.string "order_number", null: false
    t.string "status", default: "draft", null: false
    t.date "delivery_date"
    t.text "notes"
    t.string "idempotency_key"
    t.string "credit_decision"
    t.jsonb "credit_snapshot", default: {}
    t.jsonb "credit_reasons", default: []
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "discount_amount", precision: 14, scale: 2, default: "0.0"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "dispatched_at"
    t.datetime "delivered_at"
    t.text "delivery_failure_reason"
    t.jsonb "scheme_snapshot", default: {}
    t.integer "pick_status", default: 0, null: false
    t.bigint "picked_by_id"
    t.datetime "picked_at"
    t.bigint "pick_confirmed_by_id"
    t.datetime "pick_confirmed_at"
    t.datetime "rescheduled_at", comment: "When order was rescheduled due to shortage"
    t.datetime "rescheduled_from", comment: "Original creation date before reschedule"
    t.string "rescheduled_reason", comment: "Reason for reschedule (e.g., inventory_shortage)"
    t.date "planned_delivery_date", comment: "Planned delivery date for rescheduled orders"
    t.index ["branch_id", "created_at"], name: "idx_sales_orders_branch_created_at"
    t.index ["branch_id"], name: "index_sales_orders_on_branch_id"
    t.index ["created_by_id"], name: "index_sales_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_sales_orders_on_customer_id"
    t.index ["deleted_at"], name: "index_sales_orders_on_deleted_at"
    t.index ["idempotency_key"], name: "index_sales_orders_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["order_number"], name: "index_sales_orders_on_order_number"
    t.index ["organization_id", "created_at"], name: "idx_sales_orders_active_status", order: { created_at: :desc }, where: "((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'on_hold'::character varying, 'approved'::character varying, 'dispatched'::character varying])::text[]))"
    t.index ["organization_id", "order_number"], name: "index_sales_orders_on_organization_id_and_order_number", unique: true
    t.index ["organization_id"], name: "index_sales_orders_on_organization_id"
    t.index ["pick_status"], name: "index_sales_orders_on_pick_status"
    t.index ["rescheduled_at"], name: "index_sales_orders_on_rescheduled_at"
    t.index ["status"], name: "index_sales_orders_on_status"
    t.check_constraint "total_amount >= 0::numeric", name: "chk_sales_orders_total_non_negative"
  end

  create_table "scheme_applications", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "sales_order_id"
    t.bigint "scheme_id"
    t.bigint "applied_by_id"
    t.string "source", default: "preview", null: false
    t.jsonb "breakdown", default: {}, null: false
    t.datetime "applied_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_by_id"], name: "index_scheme_applications_on_applied_by_id"
    t.index ["organization_id"], name: "index_scheme_applications_on_organization_id"
    t.index ["sales_order_id", "source"], name: "index_scheme_applications_on_sales_order_id_and_source"
    t.index ["sales_order_id"], name: "index_scheme_applications_on_sales_order_id"
    t.index ["scheme_id"], name: "index_scheme_applications_on_scheme_id"
  end

  create_table "scheme_conditions", force: :cascade do |t|
    t.bigint "scheme_id", null: false
    t.string "condition_type", null: false
    t.string "operator", default: ">=", null: false
    t.jsonb "value", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["condition_type"], name: "index_scheme_conditions_on_condition_type"
    t.index ["scheme_id"], name: "index_scheme_conditions_on_scheme_id"
  end

  create_table "scheme_rewards", force: :cascade do |t|
    t.bigint "scheme_id", null: false
    t.string "reward_type", null: false
    t.string "target_scope", default: "order", null: false
    t.bigint "target_product_id"
    t.decimal "reward_value", precision: 14, scale: 4, null: false
    t.decimal "max_reward_value", precision: 14, scale: 2
    t.integer "free_per_x"
    t.integer "free_qty_per_trigger"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheme_id"], name: "index_scheme_rewards_on_scheme_id"
    t.index ["target_product_id"], name: "index_scheme_rewards_on_target_product_id"
  end

  create_table "schemes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.string "scheme_type", null: false
    t.string "status", default: "active", null: false
    t.integer "priority", default: 0, null: false
    t.boolean "exclusive", default: false, null: false
    t.date "start_date"
    t.date "end_date"
    t.integer "applicable_days", default: [], array: true
    t.string "applies_to", default: "all", null: false
    t.text "notes"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "budget_amount", precision: 14, scale: 2
    t.decimal "utilized_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.integer "budget_alert_pct", default: 80
    t.index ["branch_id"], name: "index_schemes_on_branch_id"
    t.index ["created_by_id"], name: "index_schemes_on_created_by_id"
    t.index ["organization_id", "code"], name: "index_schemes_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_schemes_on_organization_id"
    t.index ["scheme_type"], name: "index_schemes_on_scheme_type"
    t.index ["start_date", "end_date"], name: "index_schemes_on_start_date_and_end_date"
    t.index ["status"], name: "index_schemes_on_status"
  end

  create_table "sms_logs", force: :cascade do |t|
    t.string "phone_number", null: false
    t.text "message_body", null: false
    t.string "message_type"
    t.string "twilio_sid", null: false
    t.jsonb "metadata", default: {}
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sms_logs_on_created_at"
    t.index ["message_type"], name: "index_sms_logs_on_message_type"
    t.index ["phone_number"], name: "index_sms_logs_on_phone_number"
    t.index ["twilio_sid"], name: "index_sms_logs_on_twilio_sid", unique: true
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "product_id", null: false
    t.string "movement_type", null: false
    t.string "direction", default: "in", null: false
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_cost", precision: 14, scale: 2
    t.string "reference_type"
    t.bigint "reference_id"
    t.bigint "created_by_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "reference_line_id"
    t.index ["branch_id"], name: "index_stock_movements_on_branch_id"
    t.index ["created_at"], name: "index_stock_movements_on_created_at"
    t.index ["movement_type"], name: "index_stock_movements_on_movement_type"
    t.index ["organization_id", "branch_id", "product_id", "occurred_at"], name: "index_stock_movements_ledger"
    t.index ["organization_id"], name: "index_stock_movements_on_organization_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["reference_line_id"], name: "index_stock_movements_on_reference_line_id"
    t.index ["reference_type", "reference_id"], name: "index_stock_movements_on_reference"
  end

  create_table "stock_transfer_lines", force: :cascade do |t|
    t.bigint "stock_transfer_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty_requested", precision: 12, scale: 4, null: false
    t.decimal "qty_dispatched", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "qty_received", precision: 12, scale: 4, default: "0.0", null: false
    t.decimal "qty_damaged", precision: 12, scale: 4, default: "0.0", null: false
    t.string "reason_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_stock_transfer_lines_on_product_id"
    t.index ["stock_transfer_id", "product_id"], name: "index_stock_transfer_lines_on_stock_transfer_id_and_product_id", unique: true
    t.index ["stock_transfer_id"], name: "index_stock_transfer_lines_on_stock_transfer_id"
  end

  create_table "stock_transfers", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "source_branch_id", null: false
    t.bigint "destination_branch_id", null: false
    t.string "transfer_number", null: false
    t.date "transfer_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.bigint "created_by_id", null: false
    t.bigint "dispatched_by_id"
    t.datetime "dispatched_at"
    t.bigint "received_by_id"
    t.datetime "received_at"
    t.text "cancellation_reason"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_stock_transfers_on_created_by_id"
    t.index ["destination_branch_id", "status"], name: "index_stock_transfers_on_destination_branch_id_and_status"
    t.index ["destination_branch_id"], name: "index_stock_transfers_on_destination_branch_id"
    t.index ["dispatched_by_id"], name: "index_stock_transfers_on_dispatched_by_id"
    t.index ["organization_id", "transfer_number"], name: "index_stock_transfers_on_organization_id_and_transfer_number", unique: true
    t.index ["organization_id"], name: "index_stock_transfers_on_organization_id"
    t.index ["received_by_id"], name: "index_stock_transfers_on_received_by_id"
    t.index ["source_branch_id", "status"], name: "index_stock_transfers_on_source_branch_id_and_status"
    t.index ["source_branch_id"], name: "index_stock_transfers_on_source_branch_id"
    t.index ["status"], name: "index_stock_transfers_on_status"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "plan", null: false
    t.string "status", default: "pending", null: false
    t.string "razorpay_subscription_id"
    t.string "razorpay_plan_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "trial_ends_at"
    t.datetime "cancelled_at"
    t.datetime "ends_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status"], name: "index_subscriptions_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
    t.index ["plan"], name: "index_subscriptions_on_plan"
    t.index ["razorpay_subscription_id"], name: "index_subscriptions_on_razorpay_subscription_id", unique: true, where: "(razorpay_subscription_id IS NOT NULL)"
    t.index ["status"], name: "index_subscriptions_on_status"
  end

  create_table "supplier_debit_note_lines", force: :cascade do |t|
    t.bigint "supplier_debit_note_id", null: false
    t.bigint "product_id", null: false
    t.bigint "return_line_id"
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.string "hsn_code"
    t.string "batch_number"
    t.date "expiry_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_supplier_debit_note_lines_on_product_id"
    t.index ["return_line_id"], name: "index_supplier_debit_note_lines_on_return_line_id"
    t.index ["supplier_debit_note_id"], name: "idx_sdnl_debit_note"
  end

  create_table "supplier_debit_notes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "supplier_id", null: false
    t.bigint "return_request_id"
    t.bigint "created_by_id", null: false
    t.string "debit_note_number", null: false
    t.date "debit_note_date", null: false
    t.string "status", default: "draft", null: false
    t.string "reason", null: false
    t.decimal "subtotal", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "tax_total", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 14, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "issued_at"
    t.datetime "voided_at"
    t.text "void_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_supplier_debit_notes_on_branch_id"
    t.index ["created_by_id"], name: "index_supplier_debit_notes_on_created_by_id"
    t.index ["deleted_at"], name: "index_supplier_debit_notes_on_deleted_at"
    t.index ["organization_id", "debit_note_number"], name: "idx_sdn_org_number", unique: true
    t.index ["organization_id"], name: "index_supplier_debit_notes_on_organization_id"
    t.index ["return_request_id"], name: "index_supplier_debit_notes_on_return_request_id"
    t.index ["status"], name: "index_supplier_debit_notes_on_status"
    t.index ["supplier_id"], name: "index_supplier_debit_notes_on_supplier_id"
  end

  create_table "supplier_products", force: :cascade do |t|
    t.bigint "supplier_id", null: false
    t.bigint "product_id", null: false
    t.decimal "purchase_price", precision: 15, scale: 2
    t.string "supplier_sku"
    t.integer "lead_time_days"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_supplier_products_on_product_id"
    t.index ["supplier_id", "product_id"], name: "index_supplier_products_on_supplier_and_product", unique: true
    t.index ["supplier_id"], name: "index_supplier_products_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", limit: 200, null: false
    t.string "code", null: false
    t.string "status", default: "active", null: false
    t.string "phone", null: false
    t.string "email"
    t.string "contact_person"
    t.string "gstin", limit: 15
    t.string "pan", limit: 10
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "bank_name"
    t.string "bank_account"
    t.string "bank_ifsc"
    t.integer "payment_terms_days", default: 30, null: false
    t.decimal "credit_limit", precision: 15, scale: 2
    t.text "notes"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gstin"], name: "index_suppliers_on_gstin"
    t.index ["organization_id", "code"], name: "index_suppliers_on_org_code_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id", "name"], name: "index_suppliers_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_suppliers_on_organization_id"
  end

  create_table "sync_operations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "idempotency_key", null: false
    t.string "entity_type", null: false
    t.string "operation", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "server_id"
    t.text "error_message"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_sync_operations_on_idempotency_key", unique: true
    t.index ["organization_id", "entity_type"], name: "index_sync_operations_on_organization_id_and_entity_type"
    t.index ["organization_id", "status"], name: "index_sync_operations_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_sync_operations_on_organization_id"
    t.index ["user_id"], name: "index_sync_operations_on_user_id"
  end

  create_table "tier_price_list_assignments", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.bigint "price_list_id", null: false
    t.string "retailer_tier", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "retailer_tier", "price_list_id"], name: "idx_tier_pl_assignment_unique", unique: true
    t.index ["branch_id", "retailer_tier"], name: "idx_tier_pl_assignment_branch_tier"
    t.index ["branch_id"], name: "index_tier_price_list_assignments_on_branch_id"
    t.index ["price_list_id"], name: "index_tier_price_list_assignments_on_price_list_id"
  end

  create_table "trip_stops", force: :cascade do |t|
    t.bigint "delivery_trip_id", null: false
    t.bigint "sales_order_id", null: false
    t.integer "sequence", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "delivered_at"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "device_id"
    t.string "exception_code"
    t.text "delivery_notes"
    t.string "idempotency_key"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "geofence_status", default: "not_checked", comment: "within_geofence | outside_geofence | not_checked | invalid"
    t.decimal "geofence_distance_m", precision: 10, scale: 2, comment: "Distance in meters from customer address"
    t.datetime "geofence_validated_at", comment: "Timestamp when geofence validation was performed"
    t.index ["delivery_trip_id", "sequence"], name: "index_trip_stops_on_delivery_trip_id_and_sequence"
    t.index ["delivery_trip_id"], name: "index_trip_stops_on_delivery_trip_id"
    t.index ["geofence_status"], name: "idx_trip_stops_geofence_anomalies", where: "((geofence_status)::text = ANY ((ARRAY['outside_geofence'::character varying, 'not_checked'::character varying])::text[]))"
    t.index ["idempotency_key"], name: "index_trip_stops_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["sales_order_id"], name: "index_trip_stops_on_sales_order_id"
    t.index ["status"], name: "index_trip_stops_on_status"
  end

  create_table "units_of_measures", force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_units_of_measures_on_name", unique: true
    t.index ["symbol"], name: "index_units_of_measures_on_symbol", unique: true
  end

  create_table "user_identities", force: :cascade do |t|
    t.integer "identity_type", default: 0, null: false, comment: "0=password, 1=phone_otp, 2=email_magic_link, 3=google_oauth"
    t.bigint "user_id", null: false
    t.string "provider_id", null: false, comment: "username/email/phone/oauth_uid depending on identity_type"
    t.string "provider_name", comment: "google, microsoft, apple, etc. Only for OAuth identities"
    t.datetime "verified_at"
    t.datetime "last_used_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_type", "provider_id"], name: "idx_user_identity_discovery"
    t.index ["user_id", "identity_type", "provider_id"], name: "idx_user_identity_uniqueness", unique: true
    t.index ["user_id", "verified_at"], name: "idx_user_verified_identities"
    t.index ["user_id"], name: "index_user_identities_on_user_id"
  end

  create_table "user_phone_verifications", force: :cascade do |t|
    t.bigint "user_id"
    t.string "phone_number", limit: 10, null: false
    t.string "otp_code", limit: 6
    t.datetime "otp_sent_at"
    t.datetime "otp_verified_at"
    t.integer "otp_attempts", default: 0
    t.boolean "is_primary", default: false
    t.boolean "verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number", "otp_code"], name: "index_user_phone_verifications_on_phone_number_and_otp_code"
    t.index ["phone_number"], name: "index_user_phone_verifications_on_phone_number"
    t.index ["user_id", "phone_number"], name: "index_user_phone_verifications_on_user_id_and_phone_number", unique: true
    t.index ["user_id"], name: "index_user_phone_verifications_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "plan", default: "starter", null: false
    t.string "oauth_provider", comment: "OAuth provider (google, microsoft, apple, etc)"
    t.string "oauth_uid", comment: "Unique identifier from OAuth provider"
    t.boolean "phone_verified", default: false
    t.datetime "phone_verified_at"
    t.integer "preferred_auth_method", default: 0
    t.datetime "locked_until", comment: "When account lockout expires"
    t.integer "failed_login_count", default: 0, comment: "Tracks failed login attempts in current window"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["locked_until"], name: "idx_users_locked_until"
    t.index ["oauth_provider", "oauth_uid"], name: "idx_users_oauth_provider_uid", unique: true, where: "(oauth_provider IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "registration_number", null: false
    t.string "vehicle_type", default: "truck", null: false
    t.decimal "capacity_kg", precision: 10, scale: 2
    t.integer "capacity_units"
    t.bigint "default_driver_id"
    t.date "insurance_expiry"
    t.date "fitness_expiry"
    t.date "permit_expiry"
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_vehicles_on_deleted_at"
    t.index ["organization_id", "registration_number"], name: "index_vehicles_on_organization_id_and_registration_number", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_vehicles_on_organization_id"
    t.index ["status"], name: "index_vehicles_on_status"
  end

  create_table "visit_logs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "sales_rep_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "route_id"
    t.bigint "beat_schedule_id"
    t.date "visit_date", null: false
    t.datetime "checkin_at"
    t.datetime "checkout_at"
    t.decimal "gps_lat", precision: 10, scale: 6
    t.decimal "gps_lng", precision: 10, scale: 6
    t.text "notes"
    t.string "visit_status", default: "planned", null: false
    t.string "skip_reason_code"
    t.string "device_id"
    t.string "idempotency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["beat_schedule_id"], name: "index_visit_logs_on_beat_schedule_id"
    t.index ["branch_id"], name: "index_visit_logs_on_branch_id"
    t.index ["customer_id", "visit_date"], name: "index_visit_logs_customer_date"
    t.index ["idempotency_key"], name: "index_visit_logs_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["organization_id"], name: "index_visit_logs_on_organization_id"
    t.index ["route_id"], name: "index_visit_logs_on_route_id"
    t.index ["sales_rep_id", "visit_date"], name: "index_visit_logs_rep_date"
    t.index ["visit_date"], name: "index_visit_logs_on_visit_date"
    t.index ["visit_status"], name: "index_visit_logs_on_status"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.bigint "webhook_endpoint_id", null: false
    t.bigint "organization_id", null: false
    t.string "event", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "response_code"
    t.text "response_body"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status", "created_at"], name: "idx_webhook_deliveries_org_status"
    t.index ["organization_id"], name: "index_webhook_deliveries_on_organization_id"
    t.index ["webhook_endpoint_id", "event", "created_at"], name: "idx_webhook_deliveries_endpoint_event"
    t.index ["webhook_endpoint_id"], name: "index_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "webhook_endpoints", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "url", null: false
    t.string "secret", null: false
    t.string "description"
    t.jsonb "events", default: [], null: false
    t.boolean "active", default: true, null: false
    t.integer "failure_count", default: 0, null: false
    t.datetime "last_success_at"
    t.datetime "last_failure_at"
    t.string "last_failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "idx_webhook_endpoints_org_active"
    t.index ["organization_id"], name: "index_webhook_endpoints_on_organization_id"
  end

  add_foreign_key "accounting_agents", "accounting_integrations"
  add_foreign_key "accounting_agents", "organizations"
  add_foreign_key "accounting_export_files", "accounting_integrations"
  add_foreign_key "accounting_export_files", "branches"
  add_foreign_key "accounting_export_files", "organizations"
  add_foreign_key "accounting_export_files", "users", column: "generated_by_id"
  add_foreign_key "accounting_integrations", "organizations"
  add_foreign_key "accounting_integrations", "users", column: "connected_by_id"
  add_foreign_key "accounting_integrations", "users", column: "connected_by_id", name: "fk_accounting_integrations_connected_by"
  add_foreign_key "accounting_mappings", "accounting_integrations"
  add_foreign_key "accounting_mappings", "organizations"
  add_foreign_key "accounting_sync_records", "accounting_integrations"
  add_foreign_key "accounting_sync_records", "organizations"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_audit_logs", "organizations"
  add_foreign_key "admin_audit_logs", "users", column: "admin_user_id"
  add_foreign_key "admin_audit_logs", "users", column: "approved_by_id"
  add_foreign_key "advance_payments", "branches"
  add_foreign_key "advance_payments", "customers"
  add_foreign_key "advance_payments", "organizations"
  add_foreign_key "advance_payments", "payments", column: "source_payment_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "auto_post_audits", "bank_transactions"
  add_foreign_key "auto_post_audits", "payments"
  add_foreign_key "auto_post_audits", "users", column: "actor_id"
  add_foreign_key "bank_accounts", "branches"
  add_foreign_key "bank_accounts", "organizations"
  add_foreign_key "bank_statement_imports", "bank_accounts"
  add_foreign_key "bank_statement_imports", "organizations"
  add_foreign_key "bank_statement_imports", "users", column: "uploaded_by_id"
  add_foreign_key "bank_transaction_matches", "bank_transactions"
  add_foreign_key "bank_transaction_matches", "customers"
  add_foreign_key "bank_transaction_matches", "sales_invoices"
  add_foreign_key "bank_transactions", "bank_accounts"
  add_foreign_key "bank_transactions", "bank_statement_imports"
  add_foreign_key "bank_transactions", "customers", column: "matched_customer_id"
  add_foreign_key "bank_transactions", "organizations"
  add_foreign_key "bank_transactions", "payments", column: "matched_payment_id"
  add_foreign_key "bank_transactions", "sales_invoices", column: "matched_invoice_id"
  add_foreign_key "bank_transactions", "users", column: "reviewed_by_id"
  add_foreign_key "beat_retailers", "beat_schedules"
  add_foreign_key "beat_retailers", "customers"
  add_foreign_key "beat_schedules", "beats"
  add_foreign_key "beat_schedules", "branches"
  add_foreign_key "beat_schedules", "organizations"
  add_foreign_key "beat_schedules", "users", column: "sales_rep_id"
  add_foreign_key "beats", "branches"
  add_foreign_key "beats", "organizations"
  add_foreign_key "beats", "routes"
  add_foreign_key "beats", "users", column: "created_by_id"
  add_foreign_key "billing_events", "organizations"
  add_foreign_key "billing_events", "subscriptions"
  add_foreign_key "branches", "organizations"
  add_foreign_key "bulk_generations", "organizations"
  add_foreign_key "bulk_generations", "users"
  add_foreign_key "collection_schedules", "branches"
  add_foreign_key "collection_schedules", "customers"
  add_foreign_key "collection_schedules", "organizations"
  add_foreign_key "collection_schedules", "payments", column: "completed_payment_id"
  add_foreign_key "collection_schedules", "users", column: "assigned_to_id"
  add_foreign_key "credit_accounts", "branches"
  add_foreign_key "credit_accounts", "customers"
  add_foreign_key "credit_accounts", "organizations"
  add_foreign_key "credit_limit_change_requests", "credit_accounts"
  add_foreign_key "credit_limit_change_requests", "users", column: "decided_by_id"
  add_foreign_key "credit_limit_change_requests", "users", column: "requested_by_id"
  add_foreign_key "credit_note_applications", "credit_notes"
  add_foreign_key "credit_note_applications", "sales_invoices"
  add_foreign_key "credit_note_applications", "users", column: "applied_by_id"
  add_foreign_key "credit_note_lines", "credit_notes"
  add_foreign_key "credit_note_lines", "products"
  add_foreign_key "credit_note_lines", "return_lines"
  add_foreign_key "credit_notes", "branches"
  add_foreign_key "credit_notes", "customers"
  add_foreign_key "credit_notes", "organizations"
  add_foreign_key "credit_notes", "return_requests"
  add_foreign_key "credit_notes", "sales_invoices", column: "applied_to_invoice_id"
  add_foreign_key "credit_notes", "sales_orders"
  add_foreign_key "credit_notes", "users", column: "created_by_id"
  add_foreign_key "credit_policies", "organizations"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_aliases", "customers"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customers", "branches"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "routes"
  add_foreign_key "customers", "users", column: "sales_rep_id"
  add_foreign_key "delivery_proofs", "trip_stops"
  add_foreign_key "delivery_proofs", "users", column: "overridden_by_id"
  add_foreign_key "delivery_rejections", "products"
  add_foreign_key "delivery_rejections", "return_requests"
  add_foreign_key "delivery_rejections", "sales_orders"
  add_foreign_key "delivery_rejections", "trip_stops"
  add_foreign_key "delivery_rejections", "users", column: "rejected_by_id"
  add_foreign_key "delivery_trips", "branches"
  add_foreign_key "delivery_trips", "organizations"
  add_foreign_key "delivery_trips", "routes"
  add_foreign_key "delivery_trips", "users", column: "driver_id"
  add_foreign_key "delivery_trips", "vehicles"
  add_foreign_key "device_tokens", "organizations"
  add_foreign_key "device_tokens", "users"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "users", column: "generated_by_user_id"
  add_foreign_key "ewaybill_requests", "organizations"
  add_foreign_key "ewaybill_requests", "sales_invoices"
  add_foreign_key "expected_payment_references", "customers"
  add_foreign_key "expected_payment_references", "organizations"
  add_foreign_key "expected_payment_references", "sales_invoices"
  add_foreign_key "exports", "organizations"
  add_foreign_key "exports", "users", column: "requested_by_id"
  add_foreign_key "financial_years", "organizations"
  add_foreign_key "financial_years", "users", column: "closed_by_id"
  add_foreign_key "gst2b_import_lines", "gst2b_imports"
  add_foreign_key "gst2b_import_lines", "organizations"
  add_foreign_key "gst2b_import_lines", "purchase_invoices", column: "matched_purchase_invoice_id"
  add_foreign_key "gst2b_imports", "branches"
  add_foreign_key "gst2b_imports", "financial_years"
  add_foreign_key "gst2b_imports", "organizations"
  add_foreign_key "gst2b_imports", "users", column: "imported_by_id"
  add_foreign_key "gst_amendment_candidates", "gst_return_periods"
  add_foreign_key "gst_amendment_candidates", "organizations"
  add_foreign_key "gst_amendment_candidates", "users", column: "acknowledged_by_id", on_delete: :nullify
  add_foreign_key "gst_reconciliation_issues", "financial_years"
  add_foreign_key "gst_reconciliation_issues", "gst2b_imports"
  add_foreign_key "gst_reconciliation_issues", "gst_return_periods"
  add_foreign_key "gst_reconciliation_issues", "organizations"
  add_foreign_key "gst_reconciliation_issues", "users", column: "resolved_by_id"
  add_foreign_key "gst_return_periods", "branches"
  add_foreign_key "gst_return_periods", "financial_years"
  add_foreign_key "gst_return_periods", "organizations"
  add_foreign_key "gst_return_periods", "users", column: "filed_by_id"
  add_foreign_key "gst_return_periods", "users", column: "locked_by_id"
  add_foreign_key "gst_return_periods", "users", column: "reviewed_by_id"
  add_foreign_key "gst_return_snapshots", "gst_return_periods"
  add_foreign_key "gst_return_snapshots", "organizations"
  add_foreign_key "gstr1_export_records", "branches"
  add_foreign_key "gstr1_export_records", "organizations"
  add_foreign_key "gstr1_export_records", "users", column: "generated_by_id"
  add_foreign_key "inventory_levels", "branches"
  add_foreign_key "inventory_levels", "organizations"
  add_foreign_key "inventory_levels", "products"
  add_foreign_key "inventory_reservations", "branches"
  add_foreign_key "inventory_reservations", "organizations"
  add_foreign_key "inventory_reservations", "products"
  add_foreign_key "inventory_reservations", "sales_order_lines"
  add_foreign_key "inventory_reservations", "sales_orders"
  add_foreign_key "invitations", "branches"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "roles"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "invoice_generation_quarantines", "branches"
  add_foreign_key "invoice_generation_quarantines", "organizations"
  add_foreign_key "invoice_generation_quarantines", "sales_orders"
  add_foreign_key "invoice_generation_quarantines", "trip_stops"
  add_foreign_key "invoice_generation_quarantines", "users", column: "resolved_by_id"
  add_foreign_key "login_attempts", "users"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "roles"
  add_foreign_key "memberships", "users"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "onboarding_progresses", "organizations"
  add_foreign_key "onboarding_progresses", "users"
  add_foreign_key "otp_requests", "users"
  add_foreign_key "payment_allocations", "payments"
  add_foreign_key "payment_allocations", "sales_invoices"
  add_foreign_key "payment_suggestions", "bank_transactions"
  add_foreign_key "payment_suggestions", "users", column: "approved_by"
  add_foreign_key "payments", "branches"
  add_foreign_key "payments", "customers"
  add_foreign_key "payments", "organizations"
  add_foreign_key "payments", "users", column: "created_by_id"
  add_foreign_key "payments", "users", column: "reversed_by"
  add_foreign_key "pick_list_items", "pick_lists"
  add_foreign_key "pick_list_items", "products"
  add_foreign_key "pick_lists", "branches"
  add_foreign_key "pick_lists", "organizations"
  add_foreign_key "pick_lists", "sales_orders"
  add_foreign_key "pick_lists", "users", column: "picker_id"
  add_foreign_key "prepayment_skus", "branches"
  add_foreign_key "prepayment_skus", "organizations"
  add_foreign_key "prepayment_skus", "products"
  add_foreign_key "prepayment_skus", "users", column: "created_by_id"
  add_foreign_key "price_list_items", "price_lists"
  add_foreign_key "price_list_items", "products"
  add_foreign_key "price_lists", "branches"
  add_foreign_key "price_lists", "organizations"
  add_foreign_key "product_categories", "organizations"
  add_foreign_key "products", "hsn_sac_codes"
  add_foreign_key "products", "organizations"
  add_foreign_key "products", "product_categories"
  add_foreign_key "products", "units_of_measures"
  add_foreign_key "purchase_invoice_lines", "hsn_sac_codes"
  add_foreign_key "purchase_invoice_lines", "products"
  add_foreign_key "purchase_invoice_lines", "purchase_invoices"
  add_foreign_key "purchase_invoices", "branches"
  add_foreign_key "purchase_invoices", "organizations"
  add_foreign_key "purchase_invoices", "suppliers"
  add_foreign_key "purchase_invoices", "users", column: "created_by_id"
  add_foreign_key "rejection_feedbacks", "payments"
  add_foreign_key "reschedule_deliveries", "customers"
  add_foreign_key "reschedule_deliveries", "organizations"
  add_foreign_key "reschedule_deliveries", "sales_orders"
  add_foreign_key "reschedule_deliveries", "trip_stops"
  add_foreign_key "reschedule_deliveries", "trip_stops", column: "new_trip_stop_id"
  add_foreign_key "retailer_price_list_assignments", "customers"
  add_foreign_key "retailer_price_list_assignments", "price_lists"
  add_foreign_key "retailer_risk_snapshots", "customers"
  add_foreign_key "retailer_risk_snapshots", "organizations"
  add_foreign_key "return_lines", "products"
  add_foreign_key "return_lines", "return_requests"
  add_foreign_key "return_lines", "sales_order_lines"
  add_foreign_key "return_qc_items", "return_lines"
  add_foreign_key "return_qc_items", "users", column: "qc_by_id"
  add_foreign_key "return_records", "products"
  add_foreign_key "return_records", "return_requests"
  add_foreign_key "return_records", "trip_stops"
  add_foreign_key "return_requests", "branches"
  add_foreign_key "return_requests", "customers"
  add_foreign_key "return_requests", "organizations"
  add_foreign_key "return_requests", "users", column: "created_by_id"
  add_foreign_key "routes", "branches"
  add_foreign_key "routes", "organizations"
  add_foreign_key "routes", "users", column: "default_driver_id"
  add_foreign_key "routes", "vehicles"
  add_foreign_key "sales_invoice_lines", "products"
  add_foreign_key "sales_invoice_lines", "sales_invoices"
  add_foreign_key "sales_invoices", "branches"
  add_foreign_key "sales_invoices", "customers"
  add_foreign_key "sales_invoices", "organizations"
  add_foreign_key "sales_invoices", "sales_orders"
  add_foreign_key "sales_invoices", "users", column: "created_by_id"
  add_foreign_key "sales_order_freebies", "products"
  add_foreign_key "sales_order_freebies", "sales_orders"
  add_foreign_key "sales_order_freebies", "schemes"
  add_foreign_key "sales_order_lines", "price_lists"
  add_foreign_key "sales_order_lines", "products"
  add_foreign_key "sales_order_lines", "sales_orders"
  add_foreign_key "sales_orders", "branches"
  add_foreign_key "sales_orders", "customers"
  add_foreign_key "sales_orders", "organizations"
  add_foreign_key "sales_orders", "users", column: "created_by_id"
  add_foreign_key "sales_orders", "users", column: "pick_confirmed_by_id"
  add_foreign_key "sales_orders", "users", column: "picked_by_id"
  add_foreign_key "scheme_applications", "organizations"
  add_foreign_key "scheme_applications", "sales_orders"
  add_foreign_key "scheme_applications", "schemes"
  add_foreign_key "scheme_applications", "users", column: "applied_by_id"
  add_foreign_key "scheme_conditions", "schemes"
  add_foreign_key "scheme_rewards", "products", column: "target_product_id"
  add_foreign_key "scheme_rewards", "schemes"
  add_foreign_key "schemes", "branches"
  add_foreign_key "schemes", "organizations"
  add_foreign_key "schemes", "users", column: "created_by_id"
  add_foreign_key "stock_movements", "branches"
  add_foreign_key "stock_movements", "organizations"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "sales_order_lines", column: "reference_line_id"
  add_foreign_key "stock_movements", "users", column: "created_by_id"
  add_foreign_key "stock_transfer_lines", "products"
  add_foreign_key "stock_transfer_lines", "stock_transfers"
  add_foreign_key "stock_transfers", "branches", column: "destination_branch_id"
  add_foreign_key "stock_transfers", "branches", column: "source_branch_id"
  add_foreign_key "stock_transfers", "organizations"
  add_foreign_key "stock_transfers", "users", column: "created_by_id"
  add_foreign_key "stock_transfers", "users", column: "dispatched_by_id"
  add_foreign_key "stock_transfers", "users", column: "received_by_id"
  add_foreign_key "subscriptions", "organizations"
  add_foreign_key "supplier_debit_note_lines", "products"
  add_foreign_key "supplier_debit_note_lines", "return_lines"
  add_foreign_key "supplier_debit_note_lines", "supplier_debit_notes"
  add_foreign_key "supplier_debit_notes", "branches"
  add_foreign_key "supplier_debit_notes", "organizations"
  add_foreign_key "supplier_debit_notes", "return_requests"
  add_foreign_key "supplier_debit_notes", "suppliers"
  add_foreign_key "supplier_debit_notes", "users", column: "created_by_id"
  add_foreign_key "supplier_products", "products"
  add_foreign_key "supplier_products", "suppliers"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "sync_operations", "organizations"
  add_foreign_key "sync_operations", "users"
  add_foreign_key "tier_price_list_assignments", "branches"
  add_foreign_key "tier_price_list_assignments", "price_lists"
  add_foreign_key "trip_stops", "delivery_trips"
  add_foreign_key "trip_stops", "sales_orders"
  add_foreign_key "user_identities", "users"
  add_foreign_key "user_phone_verifications", "users"
  add_foreign_key "vehicles", "organizations"
  add_foreign_key "vehicles", "users", column: "default_driver_id"
  add_foreign_key "visit_logs", "beat_schedules"
  add_foreign_key "visit_logs", "branches"
  add_foreign_key "visit_logs", "customers"
  add_foreign_key "visit_logs", "organizations"
  add_foreign_key "visit_logs", "routes"
  add_foreign_key "visit_logs", "users", column: "sales_rep_id"
  add_foreign_key "webhook_deliveries", "organizations"
  add_foreign_key "webhook_deliveries", "webhook_endpoints"
  add_foreign_key "webhook_endpoints", "organizations"
end
