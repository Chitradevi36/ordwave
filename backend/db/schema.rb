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

ActiveRecord::Schema[7.1].define(version: 2026_03_05_000035) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

  create_table "beat_retailers", force: :cascade do |t|
    t.bigint "beat_schedule_id", null: false
    t.bigint "customer_id", null: false
    t.integer "sequence_number", default: 0, null: false
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
    t.index ["customer_id"], name: "index_credit_accounts_on_customer_id"
    t.index ["organization_id"], name: "index_credit_accounts_on_organization_id"
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
    t.bigint "return_request_id", null: false
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
    t.index ["branch_id"], name: "index_customers_on_branch_id"
    t.index ["channel"], name: "index_customers_on_channel"
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["deleted_at"], name: "index_customers_on_deleted_at"
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
    t.index ["proof_type"], name: "index_delivery_proofs_on_proof_type"
    t.index ["trip_stop_id"], name: "index_delivery_proofs_on_trip_stop_id"
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
    t.index ["branch_id"], name: "index_delivery_trips_on_branch_id"
    t.index ["driver_id"], name: "index_delivery_trips_on_driver_id"
    t.index ["organization_id", "trip_number"], name: "index_delivery_trips_on_organization_id_and_trip_number", unique: true
    t.index ["organization_id"], name: "index_delivery_trips_on_organization_id"
    t.index ["status"], name: "index_delivery_trips_on_status"
    t.index ["trip_date"], name: "index_delivery_trips_on_trip_date"
    t.index ["vehicle_id"], name: "index_delivery_trips_on_vehicle_id"
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
    t.index ["branch_id", "product_id"], name: "index_inventory_levels_branch_product", unique: true
    t.index ["branch_id"], name: "index_inventory_levels_on_branch_id"
    t.index ["organization_id"], name: "index_inventory_levels_on_organization_id"
    t.index ["product_id"], name: "index_inventory_levels_on_product_id"
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

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
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
    t.index ["settings"], name: "index_organizations_on_settings", using: :gin
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
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
    t.index ["branch_id"], name: "index_payments_on_branch_id"
    t.index ["created_by_id"], name: "index_payments_on_created_by_id"
    t.index ["customer_id", "status"], name: "idx_payments_customer_status"
    t.index ["customer_id"], name: "index_payments_on_customer_id"
    t.index ["metadata"], name: "idx_payments_metadata", using: :gin
    t.index ["organization_id", "payment_number"], name: "idx_payments_org_number", unique: true
    t.index ["organization_id", "status"], name: "idx_payments_org_status"
    t.index ["organization_id"], name: "index_payments_on_organization_id"
    t.index ["payment_mode"], name: "idx_payments_mode"
    t.index ["received_date"], name: "idx_payments_received_date"
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
    t.index ["email"], name: "index_pending_registrations_on_email", unique: true
    t.index ["expires_at"], name: "index_pending_registrations_on_expires_at"
    t.index ["otp_code"], name: "index_pending_registrations_on_otp_code"
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
    t.index ["branch_id"], name: "index_purchase_invoices_on_branch_id"
    t.index ["created_by_id"], name: "index_purchase_invoices_on_created_by_id"
    t.index ["deleted_at"], name: "index_purchase_invoices_on_deleted_at"
    t.index ["invoice_date"], name: "index_purchase_invoices_on_invoice_date"
    t.index ["organization_id"], name: "index_purchase_invoices_on_organization_id"
    t.index ["status"], name: "index_purchase_invoices_on_status"
    t.index ["supplier_id", "invoice_number"], name: "index_purchase_invoices_supplier_number_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["supplier_id"], name: "index_purchase_invoices_on_supplier_id"
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
    t.index ["condition"], name: "index_return_records_on_condition"
    t.index ["product_id"], name: "index_return_records_on_product_id"
    t.index ["reason_code"], name: "index_return_records_on_reason_code"
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
    t.index ["branch_id", "code"], name: "index_routes_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_routes_on_branch_id"
    t.index ["organization_id"], name: "index_routes_on_organization_id"
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
    t.index ["product_id"], name: "idx_sil_product_id"
    t.index ["product_id"], name: "index_sales_invoice_lines_on_product_id"
    t.index ["sales_invoice_id"], name: "idx_sil_invoice_id"
    t.index ["sales_invoice_id"], name: "index_sales_invoice_lines_on_sales_invoice_id"
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
    t.index ["branch_id"], name: "index_sales_invoices_on_branch_id"
    t.index ["created_by_id"], name: "index_sales_invoices_on_created_by_id"
    t.index ["customer_id", "status"], name: "idx_sales_invoices_customer_status"
    t.index ["customer_id"], name: "index_sales_invoices_on_customer_id"
    t.index ["deleted_at"], name: "index_sales_invoices_on_deleted_at"
    t.index ["invoice_date"], name: "index_sales_invoices_on_invoice_date"
    t.index ["metadata"], name: "index_sales_invoices_on_metadata", using: :gin
    t.index ["organization_id", "invoice_number"], name: "idx_sales_invoices_org_number", unique: true
    t.index ["organization_id", "status"], name: "idx_sales_invoices_org_status"
    t.index ["organization_id"], name: "index_sales_invoices_on_organization_id"
    t.index ["outstanding_amount"], name: "idx_sales_invoices_outstanding"
    t.index ["sales_order_id"], name: "index_sales_invoices_on_sales_order_id"
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
    t.integer "delivered_qty", default: 0, null: false
    t.integer "returned_qty", default: 0, null: false
    t.decimal "invoiced_qty", precision: 14, scale: 3, default: "0.0", null: false
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
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0"
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
    t.index ["branch_id"], name: "index_sales_orders_on_branch_id"
    t.index ["created_by_id"], name: "index_sales_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_sales_orders_on_customer_id"
    t.index ["deleted_at"], name: "index_sales_orders_on_deleted_at"
    t.index ["idempotency_key"], name: "index_sales_orders_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["order_number"], name: "index_sales_orders_on_order_number"
    t.index ["organization_id", "order_number"], name: "index_sales_orders_on_organization_id_and_order_number", unique: true
    t.index ["organization_id"], name: "index_sales_orders_on_organization_id"
    t.index ["status"], name: "index_sales_orders_on_status"
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
    t.index ["delivery_trip_id", "sequence"], name: "index_trip_stops_on_delivery_trip_id_and_sequence"
    t.index ["delivery_trip_id"], name: "index_trip_stops_on_delivery_trip_id"
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
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "advance_payments", "branches"
  add_foreign_key "advance_payments", "customers"
  add_foreign_key "advance_payments", "organizations"
  add_foreign_key "advance_payments", "payments", column: "source_payment_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", column: "actor_id"
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
  add_foreign_key "branches", "organizations"
  add_foreign_key "credit_accounts", "branches"
  add_foreign_key "credit_accounts", "customers"
  add_foreign_key "credit_accounts", "organizations"
  add_foreign_key "credit_limit_change_requests", "credit_accounts"
  add_foreign_key "credit_limit_change_requests", "users", column: "decided_by_id"
  add_foreign_key "credit_limit_change_requests", "users", column: "requested_by_id"
  add_foreign_key "credit_note_lines", "credit_notes"
  add_foreign_key "credit_note_lines", "products"
  add_foreign_key "credit_note_lines", "return_lines"
  add_foreign_key "credit_notes", "branches"
  add_foreign_key "credit_notes", "customers"
  add_foreign_key "credit_notes", "organizations"
  add_foreign_key "credit_notes", "return_requests"
  add_foreign_key "credit_notes", "sales_orders"
  add_foreign_key "credit_notes", "users", column: "created_by_id"
  add_foreign_key "credit_policies", "organizations"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customers", "branches"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "routes"
  add_foreign_key "customers", "users", column: "sales_rep_id"
  add_foreign_key "delivery_proofs", "trip_stops"
  add_foreign_key "delivery_proofs", "users", column: "overridden_by_id"
  add_foreign_key "delivery_trips", "branches"
  add_foreign_key "delivery_trips", "organizations"
  add_foreign_key "delivery_trips", "users", column: "driver_id"
  add_foreign_key "delivery_trips", "vehicles"
  add_foreign_key "inventory_levels", "branches"
  add_foreign_key "inventory_levels", "organizations"
  add_foreign_key "inventory_levels", "products"
  add_foreign_key "inventory_reservations", "branches"
  add_foreign_key "inventory_reservations", "organizations"
  add_foreign_key "inventory_reservations", "products"
  add_foreign_key "inventory_reservations", "sales_orders"
  add_foreign_key "invitations", "branches"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "roles"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "roles"
  add_foreign_key "memberships", "users"
  add_foreign_key "onboarding_progresses", "organizations"
  add_foreign_key "onboarding_progresses", "users"
  add_foreign_key "payment_allocations", "payments"
  add_foreign_key "payment_allocations", "sales_invoices"
  add_foreign_key "payments", "branches"
  add_foreign_key "payments", "customers"
  add_foreign_key "payments", "organizations"
  add_foreign_key "payments", "users", column: "created_by_id"
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
  add_foreign_key "retailer_price_list_assignments", "customers"
  add_foreign_key "retailer_price_list_assignments", "price_lists"
  add_foreign_key "return_lines", "products"
  add_foreign_key "return_lines", "return_requests"
  add_foreign_key "return_lines", "sales_order_lines"
  add_foreign_key "return_qc_items", "return_lines"
  add_foreign_key "return_qc_items", "users", column: "qc_by_id"
  add_foreign_key "return_records", "products"
  add_foreign_key "return_records", "trip_stops"
  add_foreign_key "return_requests", "branches"
  add_foreign_key "return_requests", "customers"
  add_foreign_key "return_requests", "organizations"
  add_foreign_key "return_requests", "users", column: "created_by_id"
  add_foreign_key "routes", "branches"
  add_foreign_key "routes", "organizations"
  add_foreign_key "sales_invoice_lines", "products"
  add_foreign_key "sales_invoice_lines", "sales_invoices"
  add_foreign_key "sales_invoices", "branches"
  add_foreign_key "sales_invoices", "customers"
  add_foreign_key "sales_invoices", "organizations"
  add_foreign_key "sales_invoices", "sales_orders"
  add_foreign_key "sales_invoices", "users", column: "created_by_id"
  add_foreign_key "sales_order_lines", "products"
  add_foreign_key "sales_order_lines", "sales_orders"
  add_foreign_key "sales_orders", "branches"
  add_foreign_key "sales_orders", "customers"
  add_foreign_key "sales_orders", "organizations"
  add_foreign_key "sales_orders", "users", column: "created_by_id"
  add_foreign_key "stock_movements", "branches"
  add_foreign_key "stock_movements", "organizations"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_transfer_lines", "products"
  add_foreign_key "stock_transfer_lines", "stock_transfers"
  add_foreign_key "stock_transfers", "branches", column: "destination_branch_id"
  add_foreign_key "stock_transfers", "branches", column: "source_branch_id"
  add_foreign_key "stock_transfers", "organizations"
  add_foreign_key "stock_transfers", "users", column: "created_by_id"
  add_foreign_key "stock_transfers", "users", column: "dispatched_by_id"
  add_foreign_key "stock_transfers", "users", column: "received_by_id"
  add_foreign_key "supplier_products", "products"
  add_foreign_key "supplier_products", "suppliers"
  add_foreign_key "suppliers", "organizations"
  add_foreign_key "tier_price_list_assignments", "branches"
  add_foreign_key "tier_price_list_assignments", "price_lists"
  add_foreign_key "trip_stops", "delivery_trips"
  add_foreign_key "trip_stops", "sales_orders"
  add_foreign_key "vehicles", "organizations"
  add_foreign_key "vehicles", "users", column: "default_driver_id"
  add_foreign_key "visit_logs", "beat_schedules"
  add_foreign_key "visit_logs", "branches"
  add_foreign_key "visit_logs", "customers"
  add_foreign_key "visit_logs", "organizations"
  add_foreign_key "visit_logs", "routes"
  add_foreign_key "visit_logs", "users", column: "sales_rep_id"
end
